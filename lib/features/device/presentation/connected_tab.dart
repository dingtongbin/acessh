// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../connection/application/session_manager.dart';
import '../../connection/application/terminal_session.dart';
import '../../terminal/presentation/terminal_screen.dart';
import '../domain/connection_type.dart';

/// 已连接 Tab:展示前台与后台会话,支持切换与关闭。
class ConnectedTab extends StatelessWidget {
  /// 创建已连接 Tab。
  const ConnectedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionManager = context.watch<SessionManager>();
    final sessions = sessionManager.aliveSessions;
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无已连接会话',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionTile(session: session);
      },
    );
  }
}

/// 单个会话条目。
class _SessionTile extends StatelessWidget {
  /// 创建会话条目。
  const _SessionTile({required this.session});

  /// 会话对象。
  final TerminalSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(switch (session.device.type) {
          ConnectionType.ssh => Icons.computer,
          ConnectionType.telnet => Icons.terminal,
          ConnectionType.serial => Icons.usb,
        }, color: scheme.primary),
      ),
      title: Text(session.label),
      subtitle: Text(
        '${session.device.type.displayName} · '
        '${session.device.host}:${session.device.port}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            session.state == TerminalSessionState.background ? '后台' : '在线',
            style: TextStyle(
              color: session.state == TerminalSessionState.background
                  ? scheme.outline
                  : Colors.green,
              fontSize: 12,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '会话操作',
            onSelected: (action) => _handleAction(context, action),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'open',
                child: ListTile(
                  leading: Icon(Icons.open_in_new),
                  title: Text('切换过去'),
                ),
              ),
              const PopupMenuItem(
                value: 'close',
                child: ListTile(
                  leading: Icon(Icons.close, color: Colors.red),
                  title: Text('关闭连接'),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _openSession(context),
    );
  }

  /// 打开(切换)到该会话的终端页。
  Future<void> _openSession(BuildContext context) async {
    final sessionManager = context.read<SessionManager>();
    sessionManager.activate(session);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TerminalScreen(session: session),
      ),
    );
  }

  /// 处理菜单动作。
  Future<void> _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'open':
        await _openSession(context);
      case 'close':
        await context.read<SessionManager>().closeSession(session);
    }
  }
}
