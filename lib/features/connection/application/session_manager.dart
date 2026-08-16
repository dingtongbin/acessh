// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/foundation.dart';

import '../../device/domain/connection_type.dart';
import '../../device/domain/device.dart';
import '../data/connection_record_repository.dart';
import 'serial_session.dart';
import 'ssh_session.dart';
import 'telnet_session.dart';
import 'terminal_session.dart';

/// 会话管理器:维护前台会话与后台挂起会话,并负责连接记录落库。
///
/// 同一设备允许同时存在多个会话(每次点击连接都新建会话),
/// 重名会话的显示名自动追加 "(N)" 标识且不会隐藏。
class SessionManager extends ChangeNotifier {
  SessionManager._();

  /// 全局唯一实例。
  static final SessionManager instance = SessionManager._();

  final ConnectionRecordRepository _recordRepository =
      ConnectionRecordRepository();

  TerminalSession? _activeSession;
  final List<TerminalSession> _backgroundSessions = [];

  /// 当前前台会话。
  TerminalSession? get activeSession => _activeSession;

  /// 后台挂起会话列表(保持连接)。
  List<TerminalSession> get backgroundSessions =>
      List.unmodifiable(_backgroundSessions);

  /// 所有存活会话(前台 + 后台)。
  List<TerminalSession> get aliveSessions => [
    ?_activeSession,
    ..._backgroundSessions,
  ];

  /// 建立到 [device] 的新连接并返回会话;失败时抛出异常并清理资源。
  ///
  /// 每次调用都创建全新会话,不会复用已有连接;
  /// 同设备已有 N 个存活会话时,新会话显示名追加 "(N)"。
  Future<TerminalSession> connect(Device device) async {
    final sameNameCount = aliveSessions
        .where((session) => session.device.name == device.name)
        .length;
    final label = sameNameCount == 0
        ? device.name
        : '${device.name} ($sameNameCount)';

    final session = switch (device.type) {
      ConnectionType.ssh => SshSession(device, label: label),
      ConnectionType.telnet => TelnetSession(
        device,
        username: device.username,
        password: device.password,
      ),
      ConnectionType.serial => SerialSession(device, label: label),
      // 桌面端会话类型(sftp/vnc/rdp/x11 及未知):UI 已拦截,此处兜底。
      _ => throw StateError('移动端暂不支持 ${device.type.displayName} 类型连接'),
    };

    final recordId = await _recordRepository.recordStart(
      deviceName: device.name,
      deviceType: device.type.storageValue,
    );
    try {
      await session.connect();
    } on Object {
      await _recordRepository.recordEnd(recordId: recordId, success: false);
      await session.close();
      rethrow;
    }
    session.connectionRecordId = recordId;
    _activeSession = session;
    notifyListeners();
    return session;
  }

  /// 将会话切换为前台(若在后台则移出后台列表)。
  void activate(TerminalSession session) {
    if (session.state == TerminalSessionState.disconnected) {
      return;
    }
    _backgroundSessions.remove(session);
    if (session.state == TerminalSessionState.background) {
      session.state = TerminalSessionState.connected;
    }
    _activeSession = session;
    notifyListeners();
  }

  /// 当前前台会话挂起到后台(连接保持),前台置空。
  void backgroundCurrent() {
    final session = _activeSession;
    if (session == null || !session.isAlive) {
      return;
    }
    session.state = TerminalSessionState.background;
    if (!_backgroundSessions.contains(session)) {
      _backgroundSessions.add(session);
    }
    _activeSession = null;
    notifyListeners();
  }

  /// 关闭并移除会话,结束连接记录。
  Future<void> closeSession(TerminalSession session) async {
    if (_activeSession == session) {
      _activeSession = null;
    }
    _backgroundSessions.remove(session);
    final recordId = session.connectionRecordId;
    if (recordId != null) {
      await _recordRepository.recordEnd(
        recordId: recordId,
        success: session.connectedOnce,
        disconnectedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    session.connectionRecordId = null;
    await session.close();
    notifyListeners();
  }
}
