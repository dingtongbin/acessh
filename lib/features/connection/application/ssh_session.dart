// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:kterm/kterm.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../../device/domain/device.dart';
import 'host_key_verifier.dart';
import 'terminal_session.dart';

/// SSH 会话实现:使用 dartssh2 建立连接并桥接 shell 到 kterm 终端。
class SshSession extends TerminalSession {
  /// 创建 SSH 会话,初始终端尺寸为 80x24。
  SshSession(
    Device device, {
    this.initialColumns = 80,
    this.initialRows = 24,
    String? label,
  }) : super(
         device,
         Terminal(
           maxLines: AppConstants.terminalMaxLines,
           platform: TerminalTargetPlatform.unknown,
         ),
         label: label,
       );

  final int initialColumns;
  final int initialRows;

  SSHClient? _client;
  SSHSession? _shell;
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<List<int>>? _stderrSub;
  bool _closing = false;

  @override
  Future<void> connect() async {
    final device = this.device;
    final socket = await SSHSocket.connect(
      device.host,
      device.port,
      timeout: AppConstants.connectionTimeout,
    );

    List<SSHKeyPair>? identities;
    if (device.usesPrivateKey) {
      final passphrase = device.privateKeyPassphrase.isEmpty
          ? null
          : device.privateKeyPassphrase;
      identities = SSHKeyPair.fromPem(device.privateKey, passphrase);
    }

    final client = SSHClient(
      socket,
      username: device.username,
      identities: identities,
      onPasswordRequest: () => device.password.isEmpty ? null : device.password,
      onUserInfoRequest: (request) {
        if (device.password.isNotEmpty) {
          return [device.password];
        }
        return null;
      },
      onVerifyHostKey: (type, fingerprint) async {
        final fingerprintText = latin1.decode(fingerprint);
        return HostKeyVerifier(device: device).verify(fingerprintText);
      },
      authTimeout: AppConstants.connectionTimeout,
      handshakeTimeout: AppConstants.connectionTimeout,
      keepAliveInterval: const Duration(seconds: 30),
    );
    _client = client;

    final shell = await client.shell(
      pty: SSHPtyConfig(
        type: 'xterm-256color',
        width: initialColumns,
        height: initialRows,
      ),
    );
    _shell = shell;
    connectedOnce = true;
    setState(TerminalSessionState.connected);

    _stdoutSub = shell.stdout.listen(
      (data) => terminal.write(utf8.decode(data, allowMalformed: true)),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.e('SSH stdout 流错误', error, stackTrace);
      },
    );
    _stderrSub = shell.stderr.listen(
      (data) => terminal.write(utf8.decode(data, allowMalformed: true)),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.e('SSH stderr 流错误', error, stackTrace);
      },
    );
    unawaited(
      shell.done.then(
        (_) => _handleDisconnected(),
        onError: (Object error, StackTrace stackTrace) {
          AppLogger.e('SSH 会话结束', error, stackTrace);
          _handleDisconnected();
        },
      ),
    );
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
    final shell = _shell;
    if (shell == null || state != TerminalSessionState.connected) {
      return;
    }
    shell.write(Uint8List.fromList(utf8.encode(text)));
  }

  @override
  void resize(int columns, int rows) {
    final shell = _shell;
    if (shell == null) {
      return;
    }
    shell.resizeTerminal(columns, rows);
  }

  @override
  Future<void> close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    setState(TerminalSessionState.disconnected);
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _shell?.close();
    _client?.close();
    try {
      await _client?.done.timeout(const Duration(seconds: 3), onTimeout: () {});
    } on Object catch (error) {
      AppLogger.d('SSH 关闭等待超时:$error');
    }
  }

  /// 底层连接断开时更新会话状态。
  void _handleDisconnected() {
    if (_closing) {
      return;
    }
    _closing = true;
    setState(TerminalSessionState.disconnected);
    terminal.write('\r\n[连接已断开]\r\n');
  }
}
