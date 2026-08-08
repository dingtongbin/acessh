// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';

/// 基于流式 [Socket] 的 Telnet 连接。
///
/// 使用 Socket 而非 RawSocket:RawSocket 的 read 按数据段读取,
/// 在服务器连续发送多个协商批次时可能漏读,导致协商无法完成。
class TelnetConnection {
  /// 创建 Telnet 连接。
  TelnetConnection({required this.host, required this.port});

  /// 主机地址。
  final String host;

  /// 端口。
  final int port;

  Socket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  bool _closed = false;

  /// 收到的数据流(原始字节块)。
  final StreamController<Uint8List> _dataController =
      StreamController<Uint8List>();

  /// 数据流。
  Stream<Uint8List> get data => _dataController.stream;

  /// 建立连接,失败时抛出异常。
  Future<void> connect() async {
    final socket = await Socket.connect(
      host,
      port,
      timeout: AppConstants.connectionTimeout,
    );
    _socket = socket;
    _subscription = socket.listen(
      (data) => _dataController.add(data),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.e('Telnet 连接错误', error, stackTrace);
      },
      onDone: () {
        if (!_dataController.isClosed) {
          _dataController.close();
        }
      },
    );
  }

  /// 发送原始字节。
  void sendBytes(List<int> bytes) {
    final socket = _socket;
    if (socket == null || _closed) {
      return;
    }
    socket.add(Uint8List.fromList(bytes));
  }

  /// 发送文本(UTF-8 编码)。
  void sendText(String text) {
    sendBytes(Uint8List.fromList(utf8.encode(text)));
  }

  /// 关闭连接。
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _subscription?.cancel();
    _socket?.destroy();
    _socket = null;
    if (!_dataController.isClosed) {
      await _dataController.close();
    }
  }
}
