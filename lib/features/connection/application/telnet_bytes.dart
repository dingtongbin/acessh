// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:typed_data';

/// Telnet 原始字节流处理。
///
/// 服务器发送的数据中,IAC 命令(0xFF 开头)与文本字节交错出现,
/// 渲染前必须剥离全部命令字节,仅保留可显示的文本与 ANSI 转义序列,
/// 否则终端会显示乱码。
abstract final class TelnetBytes {
  const TelnetBytes._();

  /// IAC 字节。
  static const int iac = 0xFF;

  /// 子协商开始。
  static const int sb = 0xFA;

  /// 子协商结束。
  static const int se = 0xF0;

  /// 两字节命令(仅 IAC + 命令,无选项字节)。
  static const Set<int> _twoByteCommands = {
    0xF0, // SE
    0xF1, // NOP
    0xF2, // DM
    0xF3, // BRK
    0xF4, // IP
    0xF5, // AO
    0xF6, // AYT
    0xF7, // EC
    0xF8, // EL
    0xF9, // GA
  };

  /// 剥离全部 IAC 命令字节,返回可渲染的原始内容。
  ///
  /// 处理规则:
  /// - IAC SB ... IAC SE 子协商整段跳过;
  /// - IAC IAC 转义为单个 0xFF;
  /// - 两字节命令(IAC CMD)跳过 2 字节;
  /// - 三字节命令(IAC CMD OPT)跳过 3 字节;
  /// - 末尾不完整命令丢弃。
  static Uint8List stripCommands(List<int> bytes) {
    final output = BytesBuilder(copy: false);
    var i = 0;
    while (i < bytes.length) {
      final byte = bytes[i];
      if (byte != iac) {
        output.addByte(byte);
        i++;
        continue;
      }
      // IAC 开头:解析命令。
      if (i + 1 >= bytes.length) {
        break; // 末尾不完整的 IAC,丢弃。
      }
      final command = bytes[i + 1];
      if (command == iac) {
        // IAC IAC 转义:输出单个 0xFF。
        output.addByte(iac);
        i += 2;
        continue;
      }
      if (command == sb) {
        // 子协商:跳转到 IAC SE 结束。
        var j = i + 2;
        var found = false;
        while (j < bytes.length - 1) {
          if (bytes[j] == iac && bytes[j + 1] == se) {
            found = true;
            break;
          }
          j++;
        }
        i = found ? j + 2 : bytes.length;
        continue;
      }
      if (_twoByteCommands.contains(command)) {
        i += 2;
        continue;
      }
      // 三字节命令(IAC CMD OPT)。
      i += 3;
    }
    return output.toBytes();
  }
}
