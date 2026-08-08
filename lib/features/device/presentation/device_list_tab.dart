// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/logging/app_logger.dart';
import '../../connection/application/session_manager.dart';
import '../../connection/presentation/connect_device.dart';
import '../application/device_controller.dart';
import '../domain/device.dart';
import 'device_edit_sheet.dart';
import 'device_list_tile.dart';
import 'device_transfer.dart';
import 'device_view_sheet.dart';
import 'sort_menu.dart';

/// 设备列表 Tab:排序行、设备列表与右下角新建悬浮按钮
/// (快速添加入口位于主页左上角)。
class DeviceListTab extends StatelessWidget {
  /// 创建设备列表 Tab。
  const DeviceListTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceController>();
    final devices = controller.filteredDevices;
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
              child: devices.isEmpty
                  ? const _EmptyDeviceState()
                  : ListView.separated(
                      itemCount: devices.length,
                      separatorBuilder: (_, _) =>
                          const Divider(indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return DeviceListTile(
                          device: device,
                          onTap: () => connectDevice(context, device),
                          onAction: (action) =>
                              _handleDeviceAction(context, device, action),
                        );
                      },
                    ),
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
      await deviceController.deleteDevice(device.name);
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
