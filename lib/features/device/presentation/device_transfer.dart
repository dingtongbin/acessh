// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/logging/app_logger.dart';
import '../application/device_controller.dart';
import '../application/device_transfer_service.dart';
import '../domain/device.dart';

/// 设备导入导出流程:
/// - 导出:多选设备 → 输入密码加密 → 生成 .acessh 文件并分享;
/// - 导入:选择 .acessh 文件 → 输入密码解密 → 逐台导入,
///   重名设备由用户选择 改名 / 跳过 / 覆盖。
abstract final class DeviceTransfer {
  const DeviceTransfer._();

  /// 导出文件扩展名。
  static const String fileExtension = 'acessh';

  /// 打开设备多选导出面板。
  static Future<void> showExportSheet(BuildContext context) async {
    final controller = context.read<DeviceController>();
    if (controller.devices.isEmpty) {
      _toast(context, '没有可导出的设备');
      return;
    }
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      builder: (context) => _DevicePickSheet(devices: controller.devices),
    );
    if (selected == null || selected.isEmpty || !context.mounted) {
      return;
    }
    final devices = controller.devices
        .where((device) => selected.contains(device.name))
        .toList();
    final password = await _askExportPassword(context);
    if (password == null || !context.mounted) {
      return;
    }
    try {
      final content = await DeviceTransferService.encryptDevices(
        devices,
        password,
      );
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}acessh_devices.$fileExtension',
      );
      await file.writeAsString(content, flush: true);
      if (!context.mounted) {
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          text: 'acessh 设备导出(${devices.length} 台)',
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('导出设备失败', error, stackTrace);
      if (context.mounted) {
        _toast(context, '导出失败:$error');
      }
    }
  }

  /// 打开设备导入流程。
  static Future<void> showImportSheet(BuildContext context) async {
    String? path;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [fileExtension],
        dialogTitle: '选择 acessh 设备文件',
      );
      path = result?.files.single.path;
    } on Object catch (error, stackTrace) {
      AppLogger.e('选择设备文件失败', error, stackTrace);
    }
    if (path == null || !context.mounted) {
      return;
    }
    String content;
    try {
      content = await File(path).readAsString();
    } on Object catch (error, stackTrace) {
      AppLogger.e('读取设备文件失败', error, stackTrace);
      if (context.mounted) {
        _toast(context, '读取文件失败:$error');
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final password = await _askImportPassword(context);
    if (password == null || !context.mounted) {
      return;
    }
    try {
      final devices = await DeviceTransferService.decryptDevices(
        content,
        password,
      );
      if (devices.isEmpty) {
        if (context.mounted) {
          _toast(context, '文件中没有设备');
        }
        return;
      }
      if (!context.mounted) {
        return;
      }
      await _importDevices(context, devices);
    } on Object catch (error, stackTrace) {
      AppLogger.e('导入设备失败', error, stackTrace);
      if (context.mounted) {
        _toast(context, '导入失败:$error(请确认密码正确)');
      }
    }
  }

  /// 逐台导入设备,重名时由用户选择处理方式。
  static Future<void> _importDevices(
    BuildContext context,
    List<Device> devices,
  ) async {
    final controller = context.read<DeviceController>();
    var imported = 0;
    var skipped = 0;
    for (final device in devices) {
      final exists = await controller.queryByName(device.name);
      if (exists != null) {
        if (!context.mounted) {
          skipped++;
          continue;
        }
        final action = await _askConflictAction(context, device.name);
        if (action == null || !context.mounted) {
          skipped++;
          continue;
        }
        switch (action.$1) {
          case _ConflictAction.skip:
            skipped++;
            continue;
          case _ConflictAction.overwrite:
            await controller.updateDevice(device);
            imported++;
            continue;
          case _ConflictAction.rename:
            await controller.addDevice(device.copyWith(name: action.$2));
            imported++;
            continue;
        }
      }
      await controller.addDevice(device);
      imported++;
    }
    await controller.load();
    if (context.mounted) {
      _toast(context, '导入完成:成功 $imported 台,跳过 $skipped 台');
    }
  }

  /// 弹窗询问冲突设备处理方式(改名/跳过/覆盖)。
  static Future<(_ConflictAction, String?)?> _askConflictAction(
    BuildContext context,
    String name,
  ) {
    return showDialog<(_ConflictAction, String?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设备已存在'),
        content: Text('设备"$name"已存在,请选择处理方式:'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((_ConflictAction.skip, null)),
            child: const Text('跳过'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((_ConflictAction.overwrite, null)),
            child: const Text('覆盖'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = await _askRename(context, name);
              if (newName != null && context.mounted) {
                Navigator.of(context).pop((_ConflictAction.rename, newName));
              }
            },
            child: const Text('改名'),
          ),
        ],
      ),
    );
  }

  /// 输入新设备名。
  static Future<String?> _askRename(BuildContext context, String oldName) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名设备'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: '新会话名(原:$oldName)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                return;
              }
              Navigator.of(context).pop(name);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 导出密码输入(两次一致)。
  static Future<String?> _askExportPassword(BuildContext context) {
    final first = TextEditingController();
    final second = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置导出密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              obscureText: true,
              decoration: const InputDecoration(labelText: '导出密码(至少 4 位)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: second,
              obscureText: true,
              decoration: const InputDecoration(labelText: '再次输入密码'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final a = first.text;
              final b = second.text;
              if (a.length < 4) {
                _toast(context, '密码至少 4 位');
                return;
              }
              if (a != b) {
                _toast(context, '两次输入不一致');
                return;
              }
              Navigator.of(context).pop(a);
            },
            child: const Text('导出'),
          ),
        ],
      ),
    );
  }

  /// 导入密码输入。
  static Future<String?> _askImportPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入导入密码'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: '导出时设置的密码'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isEmpty) {
                _toast(context, '请输入密码');
                return;
              }
              Navigator.of(context).pop(controller.text);
            },
            child: const Text('解密导入'),
          ),
        ],
      ),
    );
  }

  /// 提示消息。
  static void _toast(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 重名处理方式。
enum _ConflictAction { skip, overwrite, rename }

/// 设备多选面板。
class _DevicePickSheet extends StatefulWidget {
  /// 创建设备多选面板。
  const _DevicePickSheet({required this.devices});

  /// 可选的设备列表。
  final List<Device> devices;

  @override
  State<_DevicePickSheet> createState() => _DevicePickSheetState();
}

class _DevicePickSheetState extends State<_DevicePickSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '选择要导出的设备(${_selected.length}/${widget.devices.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selected.length == widget.devices.length) {
                        _selected.clear();
                      } else {
                        _selected.addAll(widget.devices.map((d) => d.name));
                      }
                    });
                  },
                  child: Text(
                    _selected.length == widget.devices.length ? '全不选' : '全选',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 320,
            child: ListView.builder(
              itemCount: widget.devices.length,
              itemBuilder: (context, index) {
                final device = widget.devices[index];
                return CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    device.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    '${device.type.displayName} · ${device.host}:${device.port}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: _selected.contains(device.name),
                  onChanged: (checked) {
                    setState(() {
                      if (checked ?? false) {
                        _selected.add(device.name);
                      } else {
                        _selected.remove(device.name);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(Set.of(_selected)),
              child: const Text('下一步:设置导出密码'),
            ),
          ),
        ],
      ),
    );
  }
}
