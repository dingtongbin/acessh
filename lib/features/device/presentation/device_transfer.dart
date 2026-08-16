// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toml/toml.dart';

import '../../../core/logging/app_logger.dart';
import '../../connection/data/ssh_key_repository.dart';
import '../../connection/domain/stored_key.dart';
import '../application/device_controller.dart';
import '../application/device_transfer_service.dart';
import '../data/device_repository.dart';
import '../domain/device.dart';

/// 设备导入导出流程(对齐 AceShell as9 会话包):
/// - 导出:勾选会话(文件夹递归)与密钥 → 密码(8~64 位三类字符)加密
///   → 生成 .as9 二进制包并分享;
/// - 导入:选择 .as9 → 密码解密(错误可重输)→ 会话按相对路径原样还原,
///   密钥合并进本机密钥库(用本机主密钥重新加密落盘)。
abstract final class DeviceTransfer {
  const DeviceTransfer._();

  /// 导出文件扩展名。
  static const String fileExtension = 'as9';

  /// 打开导出面板:会话树 + 密钥勾选 + 密码门控。
  static Future<void> showExportSheet(BuildContext context) async {
    final controller = context.read<DeviceController>();
    if (controller.devices.isEmpty) {
      _toast(context, '没有可导出的设备');
      return;
    }
    final keys = await SshKeyRepository().listKeys();
    if (!context.mounted) {
      return;
    }
    final result =
        await showModalBottomSheet<
          ({Set<Device> devices, Set<StoredKey> keys, String password})
        >(
          context: context,
          isScrollControlled: true,
          builder: (context) =>
              _ExportSheet(devices: controller.devices, keys: keys),
        );
    if (result == null || !context.mounted) {
      return;
    }
    try {
      final repository = DeviceRepository();
      final entries = <SessionPackageEntry>[];
      for (final device in result.devices) {
        entries.add((
          entryPath: device.folder.isEmpty
              ? '${device.name}.toml'
              : '${device.folder}/${device.name}.toml',
          bytes: await repository.readRawSession(device),
        ));
      }
      final bytes = await DeviceTransferService.exportPackage(
        sessionFiles: entries,
        keys: result.keys.toList(),
        password: result.password,
      );
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      final fileName =
          'acessh会话包_${now.year}${two(now.month)}${two(now.day)}_'
          '${two(now.hour)}${two(now.minute)}${two(now.second)}.$fileExtension';
      final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);
      if (!context.mounted) {
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/octet-stream')],
          text:
              'acessh 会话包:${result.devices.length} 个会话、'
              '${result.keys.length} 个密钥',
        ),
      );
      if (context.mounted) {
        _toast(
          context,
          '已导出 ${result.devices.length} 个会话、${result.keys.length} 个密钥',
        );
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('导出会话包失败', error, stackTrace);
      if (context.mounted) {
        _toast(context, '导出失败:$error');
      }
    }
  }

  /// 打开导入流程:选包 → 密码解密(错误可重输)→ 还原会话与合并密钥。
  static Future<void> showImportSheet(BuildContext context) async {
    String? path;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [fileExtension],
        dialogTitle: '选择 acessh 会话包',
      );
      path = result?.files.single.path;
    } on Object catch (error, stackTrace) {
      AppLogger.e('选择会话包失败', error, stackTrace);
    }
    if (path == null || !context.mounted) {
      return;
    }
    final Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } on Object catch (error, stackTrace) {
      AppLogger.e('读取会话包失败', error, stackTrace);
      if (context.mounted) {
        _toast(context, '读取文件失败:$error');
      }
      return;
    }
    if (!context.mounted) {
      return;
    }

    // 密码解密:包损坏直接终止,密码错误在弹窗内提示可重输。
    ImportPackage package;
    var errorText = '';
    while (true) {
      if (!context.mounted) {
        return;
      }
      final password = await _askImportPassword(context, errorText);
      errorText = '';
      if (password == null || !context.mounted) {
        return;
      }
      try {
        package = await DeviceTransferService.importPackage(
          bytes: bytes,
          password: password,
        );
        break;
      } on FormatException catch (error) {
        if (context.mounted) {
          _toast(context, error.message);
        }
        return;
      } on StateError catch (error) {
        errorText = error.message;
      }
    }
    if (package.sessions.isEmpty && package.keys.isEmpty) {
      if (context.mounted) {
        _toast(context, '包中没有会话或密钥');
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final summary = await _importPackage(context, package);
    if (context.mounted) {
      _toast(
        context,
        '导入完成:成功 ${summary.$1} 台设备、${summary.$2} 个密钥,'
        '跳过 ${summary.$3} 台',
      );
    }
  }

  /// 执行导入:先合并密钥到本机密钥库,再按相对路径原样还原会话。
  ///
  /// 返回 (导入设备数, 导入密钥数, 跳过设备数)。
  static Future<(int, int, int)> _importPackage(
    BuildContext context,
    ImportPackage package,
  ) async {
    final controller = context.read<DeviceController>();
    final repository = DeviceRepository();
    final keyRepository = SshKeyRepository();

    // 1. 密钥合并进本机密钥库(用本机主密钥重新加密落盘),
    //    记录 密钥名 → 新文件路径 用于设备 key_path 重映射。
    final keyPathByName = <String, String>{};
    for (final key in package.keys) {
      if (key.name.isEmpty || key.privateKey.isEmpty) {
        continue;
      }
      final imported = await keyRepository.createKey(
        privateKey: key.privateKey,
        passphrase: key.passphrase,
        name: key.name,
        createdAt: key.createdAt,
      );
      keyPathByName[key.name] = imported.filePath;
    }

    // 2. 会话按相对路径原样还原;重名由用户选择处理方式。
    var importedSessions = 0;
    var skippedSessions = 0;
    for (final entry in package.sessions) {
      var device = _parsePackageSession(entry.folder, entry.name, entry.bytes);
      if (device == null) {
        skippedSessions++;
        continue;
      }
      // key_path 重映射:设备引用的密钥若随包导入,指向本机新密钥。
      final originalKeyPath = device.keyPath;
      if (device.usesPrivateKey && originalKeyPath.isNotEmpty) {
        final keyName = originalKeyPath.split('/').last.replaceAll('.json', '');
        final newPath = keyPathByName[keyName];
        if (newPath != null) {
          device = device.copyWith(keyPath: newPath);
        }
      }

      // 冲突处理:确定目标会话名。
      var targetName = device.name;
      var skip = false;
      final exists = await controller.queryByName(
        device.name,
        folder: device.folder,
      );
      if (exists != null) {
        if (!context.mounted) {
          skippedSessions++;
          continue;
        }
        final action = await _askConflictAction(context, device.name);
        if (action == null || !context.mounted) {
          skippedSessions++;
          continue;
        }
        switch (action.$1) {
          case _ConflictAction.skip:
            skip = true;
          case _ConflictAction.overwrite:
            targetName = device.name;
          case _ConflictAction.rename:
            targetName = action.$2!;
        }
      }
      if (skip) {
        skippedSessions++;
        continue;
      }

      // 原样字节写入;重映射过 key_path 时仅替换该字段。
      await repository.writeRawSession(targetName, device.folder, entry.bytes);
      if (device.keyPath != originalKeyPath) {
        await repository.remapKeyPath(
          targetName,
          device.folder,
          oldKeyPath: originalKeyPath,
          newKeyPath: device.keyPath,
        );
      }
      importedSessions++;
    }
    await controller.load();
    return (importedSessions, keyPathByName.length, skippedSessions);
  }

  /// 从包内会话原始字节解析 Device(folder 由条目路径推导,
  /// 密码密文原样解析,不做解密)。
  static Device? _parsePackageSession(
    String folder,
    String name,
    Uint8List bytes,
  ) {
    try {
      final map = TomlDocument.parse(utf8.decode(bytes)).toMap();
      return Device.fromTomlMap(map, fallbackName: name, folder: folder);
    } on Object catch (error, stackTrace) {
      AppLogger.e('解析包内会话失败:$name', error, stackTrace);
      return null;
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

  /// 导入密码输入;密码错误时 [errorText] 非空,弹窗内提示可重输。
  static Future<String?> _askImportPassword(
    BuildContext context,
    String errorText,
  ) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入导入密码'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '导出时设置的密码',
            errorText: errorText.isEmpty ? null : errorText,
          ),
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

/// 导出面板:会话树勾选(文件夹递归)+ 密钥勾选 + 密码实时门控。
class _ExportSheet extends StatefulWidget {
  /// 创建导出面板。
  const _ExportSheet({required this.devices, required this.keys});

  /// 全部设备(含文件夹归属)。
  final List<Device> devices;

  /// 密钥库全部密钥(时间倒序,默认不勾选)。
  final List<StoredKey> keys;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  /// 勾选的设备(引用相等)。
  final Set<Device> _selectedDevices = {};

  /// 勾选的密钥。
  final Set<String> _selectedKeyNames = {};

  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// 文件夹名列表(按名称排序,仅含有设备的文件夹)。
  List<String> get _folders =>
      widget.devices
          .map((device) => device.folder)
          .where((folder) => folder.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  /// 根目录设备。
  List<Device> get _rootDevices =>
      widget.devices.where((device) => device.folder.isEmpty).toList();

  /// 文件夹内设备。
  List<Device> _folderDevices(String folder) =>
      widget.devices.where((device) => device.folder == folder).toList();

  /// 勾选数量。
  int get _sessionCount => _selectedDevices.length;

  bool get _hasSelection =>
      _selectedDevices.isNotEmpty || _selectedKeyNames.isNotEmpty;

  /// 密码实时校验结果(为空表示合规)。
  String? get _passwordError =>
      ExportPasswordPolicy.validate(_passwordController.text);

  /// 当前密码覆盖类别数。
  int get _categoryCount =>
      ExportPasswordPolicy.categoryCount(_passwordController.text);

  @override
  Widget build(BuildContext context) {
    final canExport = _hasSelection && _passwordError == null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('导出会话包', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _buildSessionSection(context),
              if (widget.keys.isNotEmpty) _buildKeySection(context),
              const Divider(height: 24),
              _buildPasswordSection(context),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: canExport ? _export : null,
                child: Text(
                  '导出($_sessionCount 会话'
                  '/${_selectedKeyNames.length} 密钥)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 会话勾选区:根目录设备 + 文件夹(勾选文件夹 = 递归包含)。
  Widget _buildSessionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '会话(已选 $_sessionCount 个)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedDevices.length == widget.devices.length) {
                    _selectedDevices.clear();
                  } else {
                    _selectedDevices.addAll(widget.devices);
                  }
                });
              },
              child: Text(
                _selectedDevices.length == widget.devices.length ? '全不选' : '全选',
              ),
            ),
          ],
        ),
        for (final device in _rootDevices)
          CheckboxListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(device.name),
            subtitle: Text(
              '${device.type.displayName} · ${device.host}:${device.port}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: _selectedDevices.contains(device),
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                _selectedDevices.add(device);
              } else {
                _selectedDevices.remove(device);
              }
            }),
          ),
        for (final folder in _folders) _buildFolderTile(context, folder),
      ],
    );
  }

  /// 文件夹条目:三态勾选(递归包含其中全部设备)。
  Widget _buildFolderTile(BuildContext context, String folder) {
    final devices = _folderDevices(folder);
    final selectedCount = devices.where(_selectedDevices.contains).length;
    final allSelected = selectedCount == devices.length;
    final noneSelected = selectedCount == 0;
    return CheckboxListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(folder, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        '文件夹 · ${devices.length} 台设备',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      tristate: true,
      // CheckboxListTile 的 tristate 在 value 为 null 时显示半选。
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (checked) => setState(() {
        if (checked == true) {
          _selectedDevices.addAll(devices);
        } else {
          _selectedDevices.removeAll(devices);
        }
      }),
      activeColor: null,
      // 半选状态:value 用 null 表示(全部未选时 false,部分选时 null)。
      value: allSelected ? true : (noneSelected ? false : null),
    );
  }

  /// 密钥勾选区(可选,默认不勾)。
  Widget _buildKeySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          '密钥(可选,已选 ${_selectedKeyNames.length} 个)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final key in widget.keys)
          CheckboxListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(key.name),
            subtitle: Text(
              '${key.passphrase.isEmpty ? '无口令' : '加密密钥'} · 创建于'
              ' ${_formatTime(key.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: _selectedKeyNames.contains(key.name),
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                _selectedKeyNames.add(key.name);
              } else {
                _selectedKeyNames.remove(key.name);
              }
            }),
          ),
      ],
    );
  }

  /// 密码区:实时门控提示(长度与字符类别)。
  Widget _buildPasswordSection(BuildContext context) {
    final error = _passwordError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('导出密码', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '8~64 位,大写/小写/数字/符号至少三类',
            errorText: error,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (error == null && _passwordController.text.isNotEmpty)
          Text(
            '已覆盖 $_categoryCount/'
            '$ExportPasswordPolicy.requiredCategories 类字符',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  /// 执行导出。
  Future<void> _export() async {
    final password = _passwordController.text;
    final selectedKeys = widget.keys
        .where((key) => _selectedKeyNames.contains(key.name))
        .toList();
    Navigator.of(context).pop((
      devices: Set.of(_selectedDevices),
      keys: selectedKeys,
      password: password,
    ));
  }

  /// 格式化毫秒时间戳。
  static String _formatTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }
}
