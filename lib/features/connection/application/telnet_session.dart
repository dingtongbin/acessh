// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:async';
import 'dart:convert';

import 'package:kterm/kterm.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../../device/domain/device.dart';
import 'telnet_bytes.dart';
import 'telnet_connection.dart';
import 'telnet_login_detector.dart';
import 'telnet_negotiator.dart';
import 'terminal_session.dart';

/// Telnet 会话实现:基于 RawSocket 直连,输出以原始字节(保留 ANSI)写入 kterm。
///
/// 连接后自动完成选项协商(否则服务器不会发送登录提示),
/// 并根据设备配置自动回填用户名与密码。
class TelnetSession extends TerminalSession {
  /// 创建 Telnet 会话,并携带用户名密码用于自动登录。
  TelnetSession(
    Device device, {
    required this.username,
    required this.password,
    String? label,
  }) : super(
         device,
         Terminal(
           maxLines: AppConstants.terminalMaxLines,
           platform: TerminalTargetPlatform.unknown,
         ),
         label: label,
       );

  /// 自动登录使用的用户名。
  final String username;

  /// 自动登录使用的密码。
  final String password;

  TelnetConnection? _connection;
  StreamSubscription<List<int>>? _dataSub;
  bool _closing = false;

  /// 自动登录状态机,检测 "login:" / "Password:" 提示并回填凭据。
  late final TelnetLoginDetector _loginDetector = TelnetLoginDetector(
    username: username,
    password: password,
  );

  /// 选项协商器,确保服务器进入登录流程。
  late final TelnetNegotiator _negotiator = TelnetNegotiator(
    onSend: (bytes) => _connection?.sendBytes(bytes),
  );

  @override
  Future<void> connect() async {
    final device = this.device;
    final connection = TelnetConnection(host: device.host, port: device.port);
    _connection = connection;
    await connection.connect();
    // 主动发起基础协商。
    _negotiator.initiate();
    _dataSub = connection.data.listen(
      _handleData,
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.e('Telnet 数据流错误', error, stackTrace);
      },
      onDone: _handleDisconnected,
    );
    setState(TerminalSessionState.connected);
  }

  /// 处理一块原始数据:协商、自动登录、剥离命令后渲染。
  void _handleData(List<int> data) {
    if (_closing) {
      return;
    }
    _negotiator.processBytes(data);
    // 剥离 IAC 命令,保留文本与 ANSI 序列。
    final clean = TelnetBytes.stripCommands(data);
    if (clean.isEmpty) {
      return;
    }
    final text = utf8.decode(clean, allowMalformed: true);
    _loginDetector.process(
      text,
      onSend: (String loginText) => sendText(loginText),
    );
    if (state != TerminalSessionState.connected) {
      return;
    }
    terminal.write(text);
  }

  @override
  Future<void> reconnect() async {
    await close();
    _closing = false;
    _loginDetector.reset();
    setState(TerminalSessionState.connecting);
    await connect();
  }

  @override
  void sendText(String text) {
    final connection = _connection;
    if (connection == null || state != TerminalSessionState.connected) {
      return;
    }
    connection.sendText(text);
  }

  @override
  void resize(int columns, int rows) {
    // Telnet 无终端尺寸协商,忽略。
  }

  @override
  Future<void> close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    setState(TerminalSessionState.disconnected);
    await _dataSub?.cancel();
    await _connection?.close();
    _connection = null;
  }

  /// 底层断开时更新状态并提示用户。
  void _handleDisconnected() {
    if (_closing) {
      return;
    }
    _closing = true;
    setState(TerminalSessionState.disconnected);
    terminal.write('\r\n[连接已断开]\r\n');
  }
}
