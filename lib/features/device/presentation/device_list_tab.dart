// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/logging/app_logger.dart';
import '../../connection/application/session_manager.dart';
import '../../connection/presentation/connect_device.dart';
import '../application/device_controller.dart';
import '../data/device_repository.dart';
import '../domain/device.dart';
import 'device_edit_sheet.dart';
import 'device_list_tile.dart';
import 'device_transfer.dart';
import 'device_view_sheet.dart';
import 'sort_menu.dart';

/// 设备列表 Tab:排序行、文件夹分组设备列表与右下角新建悬浮按钮
/// (快速添加入口位于主页左上角)。
///
/// 常规展示按文件夹分组(根目录最前,文件夹头可折叠/展开);
/// 搜索或标签过滤时平铺显示命中设备,并附加所属文件夹前缀。
class DeviceListTab extends StatelessWidget {
  /// 创建设备列表 Tab。
  const DeviceListTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceController>();
    final devices = controller.filteredDevices;
    final searching =
        controller.keyword.isNotEmpty || controller.selectedTags.isNotEmpty;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '共 ${devices.length} 台设备'
                      '${controller.keyword.isEmpty ? '' : ' · 搜索"${controller.keyword}"'}'
                      '${controller.selectedTags.isEmpty ? '' : ' · 标签:${controller.selectedTags.join("、")}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    tooltip: '导入设备',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => DeviceTransfer.showImportSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_upload_outlined, size: 20),
                    tooltip: '导出设备',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => DeviceTransfer.showExportSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 20,
                    ),
                    tooltip: '新建文件夹',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _createFolder(context, controller),
                  ),
                  SortMenu(
                    field: controller.sortField,
                    direction: controller.sortDirection,
                    onChanged: controller.setSort,
                  ),
                ],
              ),
            ),
            // 标签筛选 chips(多选聚合)。
            if (controller.availableTags.isNotEmpty)
              _TagFilterBar(controller: controller),
            const SizedBox(height: 4),
            Expanded(
              child: _buildList(context, controller, devices, searching),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            shape: const CircleBorder(),
            tooltip: '新建设备',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => const DeviceEditSheet(),
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  /// 构建列表:搜索/过滤时平铺,否则按文件夹分组。
  Widget _buildList(
    BuildContext context,
    DeviceController controller,
    List<Device> devices,
    bool searching,
  ) {
    if (devices.isEmpty && controller.folders.isEmpty) {
      return const _EmptyDeviceState();
    }
    if (searching) {
      return ListView.separated(
        itemCount: devices.length,
        separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final device = devices[index];
          return DeviceListTile(
            device: device,
            folderPrefix: device.folder.isEmpty ? null : device.folder,
            onTap: () => connectDevice(context, device),
            onAction: (action) => _handleDeviceAction(context, device, action),
          );
        },
      );
    }
    final items = <Widget>[];
    // 根目录设备组排最前,组内保持现有排序。
    for (final device in devices.where((d) => d.folder.isEmpty)) {
      items.add(
        DeviceListTile(
          device: device,
          onTap: () => connectDevice(context, device),
          onAction: (action) => _handleDeviceAction(context, device, action),
        ),
      );
      items.add(const Divider(indent: 16, endIndent: 16));
    }
    for (final folder in controller.folders) {
      final folderDevices = devices
          .where((device) => device.folder == folder)
          .toList();
      final collapsed = controller.collapsedFolders.contains(folder);
      items.add(
        _FolderHeader(
          name: folder,
          count: folderDevices.length,
          collapsed: collapsed,
          onToggle: () => controller.toggleFolder(folder),
          onRename: () => _renameFolder(context, controller, folder),
          onDelete: () => _deleteFolder(context, controller, folder),
        ),
      );
      if (!collapsed) {
        for (final device in folderDevices) {
          items.add(
            DeviceListTile(
              device: device,
              onTap: () => connectDevice(context, device),
              onAction: (action) =>
                  _handleDeviceAction(context, device, action),
            ),
          );
          items.add(const Divider(indent: 16, endIndent: 16));
        }
      }
    }
    return ListView(children: items);
  }

  /// 新建文件夹对话框。
  Future<void> _createFolder(
    BuildContext context,
    DeviceController controller,
  ) async {
    final name = await _askFolderName(context, '新建文件夹', '文件夹名');
    if (name == null || !context.mounted) {
      return;
    }
    try {
      await controller.addFolder(name);
    } on Object catch (error, stackTrace) {
      AppLogger.e('新建文件夹失败', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建失败:$error')));
      }
    }
  }

  /// 重命名文件夹对话框。
  Future<void> _renameFolder(
    BuildContext context,
    DeviceController controller,
    String folder,
  ) async {
    final name = await _askFolderName(
      context,
      '重命名文件夹',
      '新文件夹名',
      initial: folder,
    );
    if (name == null || name == folder || !context.mounted) {
      return;
    }
    try {
      await controller.renameFolder(folder, name);
    } on Object catch (error, stackTrace) {
      AppLogger.e('重命名文件夹失败', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('重命名失败:$error')));
      }
    }
  }

  /// 删除文件夹确认对话框(会同时删除文件夹内全部设备)。
  Future<void> _deleteFolder(
    BuildContext context,
    DeviceController controller,
    String folder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text(
          '确定删除文件夹"$folder"吗?\n'
          '文件夹内的全部设备将一并删除,此操作不可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final sessionManager = context.read<SessionManager>();
    // 关闭文件夹内所有存活会话,避免删除设备后残留连接。
    final sessions = sessionManager.aliveSessions
        .where((session) => session.device.folder == folder)
        .toList();
    for (final session in sessions) {
      await sessionManager.closeSession(session);
    }
    if (!context.mounted) {
      return;
    }
    try {
      await controller.deleteFolder(folder);
    } on Object catch (error, stackTrace) {
      AppLogger.e('删除文件夹失败', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败:$error')));
      }
    }
  }

  /// 文件夹名输入对话框(校验保留名与非法字符),返回 null 表示取消。
  Future<String?> _askFolderName(
    BuildContext context,
    String title,
    String label, {
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label, errorText: errorText),
            onSubmitted: (value) {
              final error = DeviceRepository.folderNameError(value);
              if (error != null) {
                setDialogState(() => errorText = error);
                return;
              }
              Navigator.of(context).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final error = DeviceRepository.folderNameError(controller.text);
                if (error != null) {
                  setDialogState(() => errorText = error);
                  return;
                }
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  /// 处理设备条目的菜单动作。
  Future<void> _handleDeviceAction(
    BuildContext context,
    Device device,
    DeviceAction action,
  ) async {
    switch (action) {
      case DeviceAction.connect:
        await connectDevice(context, device);
      case DeviceAction.view:
        await showModalBottomSheet<void>(
          context: context,
          builder: (context) => DeviceViewSheet(device: device),
        );
      case DeviceAction.edit:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => DeviceEditSheet(device: device),
        );
      case DeviceAction.delete:
        await _confirmDelete(context, device);
    }
  }

  /// 弹窗确认删除设备。
  Future<void> _confirmDelete(BuildContext context, Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除设备'),
        content: Text('确定删除会话"${device.name}"吗?此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final sessionManager = context.read<SessionManager>();
    // 设备可能同时存在多个同名会话,删除设备时全部关闭。
    final sessions = sessionManager.aliveSessions
        .where((session) => session.device.name == device.name)
        .toList();
    for (final session in sessions) {
      await sessionManager.closeSession(session);
    }
    if (!context.mounted) {
      return;
    }
    final deviceController = context.read<DeviceController>();
    try {
      await deviceController.deleteDevice(device.name, folder: device.folder);
    } on Object catch (error, stackTrace) {
      AppLogger.e('删除设备失败', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败:$error')));
      }
    }
  }
}

/// 文件夹分组头部:展示名称与设备数,点击折叠/展开,菜单可重命名/删除。
class _FolderHeader extends StatelessWidget {
  /// 创建文件夹头部。
  const _FolderHeader({
    required this.name,
    required this.count,
    required this.collapsed,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });

  /// 文件夹名。
  final String name;

  /// 文件夹内设备数。
  final int count;

  /// 是否折叠。
  final bool collapsed;

  /// 切换折叠回调。
  final VoidCallback onToggle;

  /// 重命名回调。
  final VoidCallback onRename;

  /// 删除回调。
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(Icons.folder, color: scheme.primary),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$count 台设备'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(collapsed ? Icons.expand_more : Icons.expand_less),
          PopupMenuButton<String>(
            tooltip: '文件夹操作',
            onSelected: (action) => switch (action) {
              'rename' => onRename(),
              'delete' => onDelete(),
              _ => null,
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.drive_file_rename_outline),
                  title: Text('重命名'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('删除'),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: onToggle,
    );
  }
}

/// 标签筛选条:横向滚动 chips,多选聚合过滤。
class _TagFilterBar extends StatelessWidget {
  /// 创建标签筛选条。
  const _TagFilterBar({required this.controller});

  /// 设备控制器。
  final DeviceController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedTags;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                label: const Text('全部'),
                onPressed: controller.clearTags,
              ),
            ),
          for (final tag in controller.availableTags)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilterChip(
                visualDensity: VisualDensity.compact,
                label: Text(tag),
                selected: selected.contains(tag),
                onSelected: (_) => controller.toggleTag(tag),
              ),
            ),
        ],
      ),
    );
  }
}

/// 设备列表为空时的提示。
class _EmptyDeviceState extends StatelessWidget {
  /// 创建空状态。
  const _EmptyDeviceState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            '暂无设备,点击左上角 + 号或右下角按钮添加',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
