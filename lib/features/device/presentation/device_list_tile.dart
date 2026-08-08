// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../domain/connection_type.dart';
import '../domain/device.dart';

/// 设备条目的菜单动作。
enum DeviceAction { connect, view, edit, delete }

/// 设备列表条目:展示类型、会话名、主机与最近登录时间,
/// 右侧固定三点菜单,点击条目或长按均可弹出操作菜单。
class DeviceListTile extends StatelessWidget {
  /// 创建设备条目。
  const DeviceListTile({
    required this.device,
    required this.onTap,
    required this.onAction,
    super.key,
  });

  /// 设备数据。
  final Device device;

  /// 点击条目回调。
  final VoidCallback onTap;

  /// 菜单动作回调。
  final ValueChanged<DeviceAction> onAction;

  /// 类型图标。
  IconData get _typeIcon => switch (device.type) {
    ConnectionType.ssh => Icons.computer,
    ConnectionType.telnet => Icons.terminal,
    ConnectionType.serial => Icons.usb,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = device.note.isNotEmpty
        ? '${device.note} · ${device.host}:${device.port} · 打开 ${device.openCount} 次'
        : '${device.host}:${device.port} · 打开 ${device.openCount} 次 · '
              '最近 ${DateFormatter.formatMillis(device.lastConnectedAt)}';

    final menu = PopupMenuButton<DeviceAction>(
      tooltip: '更多操作',
      onSelected: onAction,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: DeviceAction.connect,
          child: ListTile(leading: Icon(Icons.play_arrow), title: Text('连接')),
        ),
        PopupMenuItem(
          value: DeviceAction.view,
          child: ListTile(
            leading: Icon(Icons.visibility_outlined),
            title: Text('查看'),
          ),
        ),
        PopupMenuItem(
          value: DeviceAction.edit,
          child: ListTile(leading: Icon(Icons.edit), title: Text('编辑')),
        ),
        PopupMenuItem(
          value: DeviceAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('删除'),
          ),
        ),
      ],
    );

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showActionSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(_typeIcon, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          device.name,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        device.type.displayName,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: scheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            menu,
          ],
        ),
      ),
    );
  }

  /// 长按弹出与三点菜单一致的底部操作面板。
  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                device.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${device.host}:${device.port} · ${device.type.displayName}',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('连接'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onAction(DeviceAction.connect);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('查看'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onAction(DeviceAction.view);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onAction(DeviceAction.edit);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onAction(DeviceAction.delete);
              },
            ),
          ],
        ),
      ),
    );
  }
}
