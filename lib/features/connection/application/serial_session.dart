// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:kterm/kterm.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../../device/domain/device.dart';
import 'terminal_session.dart';

/// 串口会话实现:通过 libserialport 读写串口,输出写入 kterm。
///
/// libserialport 仅提供非阻塞/阻塞读接口,没有事件回调,
/// 因此使用 10ms 间隔的异步轮询循环读取数据。
class SerialSession extends TerminalSession {
  /// 创建串口会话。
  SerialSession(Device device, {String? label})
    : super(
        device,
        Terminal(
          maxLines: AppConstants.terminalMaxLines,
          platform: TerminalTargetPlatform.unknown,
        ),
        label: label,
      );

  SerialPort? _port;
  bool _closing = false;
  bool _reading = false;

  /// 当前可用串口列表,用于界面选择。
  static List<String> availablePorts() {
    try {
      return SerialPort.availablePorts;
    } on Object catch (error, stackTrace) {
      AppLogger.e('枚举串口失败', error, stackTrace);
      return const [];
    }
  }

  @override
  Future<void> connect() async {
    final device = this.device;
    final port = SerialPort(device.host);
    final config = SerialPortConfig()..baudRate = device.baudRate;
    port.config = config;
    if (!port.openReadWrite()) {
      port.dispose();
      throw StateError(
        '打开串口失败:${device.host}'
        '${SerialPort.lastError == null ? '' : '(${SerialPort.lastError})'}',
      );
    }
    _port = port;
    connectedOnce = true;
    setState(TerminalSessionState.connected);
    unawaited(_readLoop());
  }

  /// 轮询读取串口数据并写入终端。
  Future<void> _readLoop() async {
    if (_reading) {
      return;
    }
    _reading = true;
    while (!_closing) {
      final port = _port;
      if (port == null) {
        break;
      }
      try {
        final available = port.bytesAvailable;
        if (available > 0) {
          final data = port.read(available, timeout: 100);
          if (data.isNotEmpty) {
            terminal.write(utf8.decode(data, allowMalformed: true));
          }
        }
      } on Object catch (error, stackTrace) {
        AppLogger.e('串口读取失败', error, stackTrace);
        _handleDisconnected();
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _reading = false;
  }

  @override
  Future<void> reconnect() async {
    await close();
    _closing = false;
    setState(TerminalSessionState.connecting);
    await connect();
  }

  @override
  void sendText(String text) {
    final port = _port;
    if (port == null || state != TerminalSessionState.connected) {
      return;
    }
    try {
      port.write(Uint8List.fromList(utf8.encode(text)), timeout: 100);
    } on Object catch (error, stackTrace) {
      AppLogger.e('串口写入失败', error, stackTrace);
    }
  }

  @override
  void resize(int columns, int rows) {
    // 串口无终端尺寸协商,忽略。
  }

  @override
  Future<void> close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    setState(TerminalSessionState.disconnected);
    final port = _port;
    _port = null;
    if (port != null) {
      try {
        port.close();
      } on Object catch (error, stackTrace) {
        AppLogger.e('关闭串口失败', error, stackTrace);
      }
      port.dispose();
    }
  }

  /// 串口异常断开时更新状态并提示用户。
  void _handleDisconnected() {
    if (_closing) {
      return;
    }
    _closing = true;
    setState(TerminalSessionState.disconnected);
    terminal.write('\r\n[连接已断开]\r\n');
  }
}
