// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../connection/application/session_manager.dart';
import '../../connection/application/terminal_session.dart';
import '../../device/domain/connection_type.dart';
import 'terminal_screen.dart';

/// 后台会话列表底部弹出层:展示全部存活会话,点击可切换过去。
class BackgroundSessionsSheet extends StatelessWidget {
  /// 创建后台会话弹出层。
  const BackgroundSessionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionManager = context.watch<SessionManager>();
    final sessions = sessionManager.aliveSessions;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '后台连接',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              // 固定高度:内容少时也保持可用的操作区域。
              const SizedBox(
                height: 320,
                child: Center(child: Text('当前没有后台会话')),
              )
            else
              SizedBox(
                height: 320,
                child: ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return _SessionListItem(session: session);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 后台会话列表条目。
class _SessionListItem extends StatelessWidget {
  /// 创建会话条目。
  const _SessionListItem({required this.session});

  /// 会话对象。
  final TerminalSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBackground = session.state == TerminalSessionState.background;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(
        switch (session.device.type) {
          ConnectionType.ssh => Icons.computer,
          ConnectionType.telnet => Icons.terminal,
          ConnectionType.serial => Icons.usb,
        },
        size: 20,
        color: scheme.primary,
      ),
      title: Text(session.label, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(
        '${session.device.type.displayName} · '
        '${isBackground ? '后台挂起' : '当前会话'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        final sessionManager = context.read<SessionManager>();
        sessionManager.activate(session);
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => TerminalScreen(session: session),
          ),
        );
      },
    );
  }
}
