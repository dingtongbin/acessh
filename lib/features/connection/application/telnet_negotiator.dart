// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// Telnet 选项协商器:完整响应服务器的 WILL/DO/SB 请求。
///
/// 多数 telnet 服务器(如 Linux telnetd)在客户端完成选项协商前不会发送
/// 登录提示,因此必须响应全部协商,包括 TERMINAL_TYPE 等子协商,
/// 否则连接看起来"无任何内容且无法输入"。
///
/// 直接解析原始字节流,不依赖外部解析器(解析器可能丢失
/// SB 子协商命令,导致协商无法完成)。
class TelnetNegotiator {
  /// 创建协商器。
  TelnetNegotiator({required this.onSend});

  /// 发送原始字节回调。
  final void Function(List<int> bytes) onSend;

  /// IAC 字节。
  static const int _iac = 0xFF;

  /// WILL。
  static const int _will = 0xFB;

  /// WONT。
  static const int _wont = 0xFC;

  /// DO。
  static const int _do = 0xFD;

  /// DONT。
  static const int _dont = 0xFE;

  /// 子协商开始。
  static const int _sb = 0xFA;

  /// 子协商结束。
  static const int _se = 0xF0;

  /// 子协商 SEND 请求。
  static const int _send = 0x01;

  /// 子协商 IS 响应。
  static const int _is = 0x00;

  /// 主动发起基础协商(WILL ECHO / WILL SGA),连接建立后调用一次。
  void initiate() {
    onSend([_iac, _will, 1]); // ECHO
    onSend([_iac, _will, 3]); // SUPPRESS_GO_AHEAD
  }

  /// 从原始字节流解析并响应全部 IAC 命令。
  void processBytes(List<int> bytes) {
    var i = 0;
    while (i < bytes.length) {
      if (bytes[i] != _iac) {
        i++;
        continue;
      }
      if (i + 1 >= bytes.length) {
        break; // 末尾不完整的 IAC,忽略。
      }
      final command = bytes[i + 1];
      if (command == _iac) {
        // IAC IAC 转义,跳过。
        i += 2;
        continue;
      }
      if (command == _sb) {
        i = _handleSubnegotiation(bytes, i);
        continue;
      }
      // WILL/WONT/DO/DONT + 选项字节(三字节命令)。
      if (i + 2 < bytes.length) {
        _respond(command, bytes[i + 2]);
        i += 3;
      } else {
        i += 2;
      }
    }
  }

  /// 处理子协商:跳转到 IAC SE,并响应 SEND 请求。
  ///
  /// 返回处理后的下标。
  int _handleSubnegotiation(List<int> bytes, int start) {
    if (start + 2 >= bytes.length) {
      return bytes.length;
    }
    final option = bytes[start + 2];
    // 查找 IAC SE 结束。
    var j = start + 3;
    var found = false;
    while (j < bytes.length - 1) {
      if (bytes[j] == _iac && bytes[j + 1] == _se) {
        found = true;
        break;
      }
      j++;
    }
    if (!found) {
      return bytes.length; // 未闭合的子协商,忽略剩余内容。
    }
    final payload = bytes.sublist(start + 3, j);
    if (payload.isNotEmpty && payload.first == _send) {
      _respondSubnegotiation(option);
    }
    return j + 2;
  }

  /// 响应 WILL/WONT/DO/DONT:向服务器回送对应的 DO/DONT/WILL/WONT。
  void _respond(int command, int option) {
    final responseType = switch (command) {
      _will => _do,
      _wont => _dont,
      _do => _will,
      _dont => _wont,
      _ => null,
    };
    if (responseType != null) {
      onSend([_iac, responseType, option]);
    }
  }

  /// 响应子协商 SEND 请求(SB ... SEND IAC SE)。
  void _respondSubnegotiation(int option) {
    final response = switch (option) {
      24 => [_is, ...'xterm'.codeUnits], // TERMINAL_TYPE
      32 => [_is, ...'9600,9600'.codeUnits], // TERMINAL_SPEED
      35 => [_is, ...'localhost:0'.codeUnits], // X_DISPLAY_LOCATION
      39 => [_is], // NEW_ENVIRON(空环境)
      _ => null,
    };
    if (response == null) {
      return;
    }
    onSend([_iac, _sb, option, ...response, _iac, _se]);
  }
}
