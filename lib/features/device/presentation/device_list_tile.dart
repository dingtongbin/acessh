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
///
/// 移动端暂不支持的会话类型(sftp/vnc/rdp/x11 等)置灰展示,
/// 点击与"连接"入口仅提示,不发起连接。
class DeviceListTile extends StatelessWidget {
  /// 创建设备条目。
  const DeviceListTile({
    required this.device,
    required this.onTap,
    required this.onAction,
    this.folderPrefix,
    super.key,
  });

  /// 设备数据。
  final Device device;

  /// 点击条目回调。
  final VoidCallback onTap;

  /// 菜单动作回调。
  final ValueChanged<DeviceAction> onAction;

  /// 所属文件夹名(搜索/标签过滤平铺展示时附加,分组展示时为 null)。
  final String? folderPrefix;

  /// 类型图标。
  IconData get _typeIcon => switch (device.type) {
    ConnectionType.ssh => Icons.computer,
    ConnectionType.telnet => Icons.terminal,
    ConnectionType.serial => Icons.usb,
    ConnectionType.sftp => Icons.folder_shared,
    ConnectionType.vnc => Icons.tv,
    ConnectionType.rdp => Icons.desktop_windows,
    ConnectionType.x11 => Icons.monitor,
    ConnectionType.unsupported => Icons.help_outline,
  };

  /// 点击条目:不支持的类型仅提示,不发起连接。
  void _handleTap(BuildContext context) {
    if (!device.isSupportedOnMobile) {
      _showUnsupportedTip(context);
      return;
    }
    onTap();
  }

  /// 弹出"移动端暂不支持"提示。
  void _showUnsupportedTip(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('移动端暂不支持 ${device.type.displayName} 类型连接')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final supported = device.isSupportedOnMobile;
    final folderLabel = folderPrefix == null ? '' : '[$folderPrefix] ';
    final subtitle = device.note.isNotEmpty
        ? '$folderLabel${device.note} · ${device.host}:${device.port} · '
              '打开 ${device.openCount} 次'
        : '$folderLabel${device.host}:${device.port} · '
              '打开 ${device.openCount} 次 · '
              '最近 ${DateFormatter.formatMillis(device.lastConnectedAt)}';

    final menu = PopupMenuButton<DeviceAction>(
      tooltip: '更多操作',
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: DeviceAction.connect,
          enabled: supported,
          child: const ListTile(
            leading: Icon(Icons.play_arrow),
            title: Text('连接'),
          ),
        ),
        const PopupMenuItem(
          value: DeviceAction.view,
          child: ListTile(
            leading: Icon(Icons.visibility_outlined),
            title: Text('查看'),
          ),
        ),
        const PopupMenuItem(
          value: DeviceAction.edit,
          child: ListTile(leading: Icon(Icons.edit), title: Text('编辑')),
        ),
        const PopupMenuItem(
          value: DeviceAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('删除'),
          ),
        ),
      ],
    );

    return InkWell(
      onTap: () => _handleTap(context),
      onLongPress: () => _showActionSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: supported
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              child: Icon(
                _typeIcon,
                color: supported ? scheme.primary : scheme.outline,
              ),
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: supported ? null : scheme.outline,
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        device.type.displayName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: supported ? scheme.primary : scheme.outline,
                        ),
                      ),
                      if (!supported) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '移动端暂不支持',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: scheme.onErrorContainer,
                                  fontSize: 10,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: supported ? null : scheme.outline,
                    ),
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
                if (device.isSupportedOnMobile) {
                  onAction(DeviceAction.connect);
                } else {
                  _showUnsupportedTip(context);
                }
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
