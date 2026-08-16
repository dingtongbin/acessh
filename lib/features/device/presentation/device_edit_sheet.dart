// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../../connection/application/ssh_key_service.dart';
import '../../connection/data/ssh_key_repository.dart';
import '../../connection/domain/stored_key.dart';
import '../application/device_controller.dart';
import '../domain/auth_method.dart';
import '../domain/connection_type.dart';
import '../domain/device.dart';
import 'serial_port_field.dart';
import 'ssh_key_picker_sheet.dart';

/// 新建/编辑设备底部弹窗,支持密码与私钥认证。
///
/// 私钥认证时从全局密钥库选择/导入密钥(密钥独立于设备存储,
/// 本机生成一次即可被多台设备引用);设备可归属某个文件夹(空为根目录)。
class DeviceEditSheet extends StatefulWidget {
  /// 创建设备编辑弹窗;[device] 为空表示新建。
  const DeviceEditSheet({this.device, super.key});

  /// 待编辑的设备,为空时表示新建。
  final Device? device;

  @override
  State<DeviceEditSheet> createState() => _DeviceEditSheetState();
}

class _DeviceEditSheetState extends State<DeviceEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _noteController;
  late final TextEditingController _tagController;
  late ConnectionType _type;
  late AuthMethod _authMethod;
  late int _baudRate;
  late String _folder;

  /// 当前选中的密钥(私钥认证时使用)。
  String _selectedKeyPath = '';
  String _selectedKeyName = '';
  String _selectedKeyPrivateKey = '';
  String _selectedKeyPassphrase = '';

  Device? get _device => widget.device;

  bool get _isEditing => _device != null;

  bool get _isSerial => _type == ConnectionType.serial;

  @override
  void initState() {
    super.initState();
    final device = _device;
    _nameController = TextEditingController(text: device?.name ?? '');
    _hostController = TextEditingController(text: device?.host ?? '');
    _portController = TextEditingController(
      text: device == null
          ? '${AppConstants.defaultSshPort}'
          : '${device.port}',
    );
    _usernameController = TextEditingController(text: device?.username ?? '');
    _passwordController = TextEditingController(text: device?.password ?? '');
    _noteController = TextEditingController(text: device?.note ?? '');
    _tagController = TextEditingController(text: device?.tag ?? '');
    _type = device?.type ?? ConnectionType.ssh;
    _authMethod = device?.authMethod ?? AuthMethod.password;
    _baudRate = device?.baudRate ?? AppConstants.defaultSerialBaudRate;
    _folder = device?.folder ?? '';
    _selectedKeyPath = device?.keyPath ?? '';
    _selectedKeyName = _keyNameFromPath(_selectedKeyPath);
    _selectedKeyPrivateKey = device?.privateKey ?? '';
    _selectedKeyPassphrase = device?.privateKeyPassphrase ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? '编辑设备' : '新建设备',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '会话名(主键,唯一)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? '请输入会话名' : null,
              ),
              const SizedBox(height: 8),
              if (!_isEditing || _device!.isSupportedOnMobile)
                SegmentedButton<ConnectionType>(
                  segments: [
                    // 新建只提供移动端支持的三种类型;
                    // 编辑支持类型设备时同样只显示这三种。
                    for (final type in ConnectionType.values.where(
                      (type) => type.isSupportedOnMobile,
                    ))
                      ButtonSegment(value: type, label: Text(type.displayName)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _type = selection.first;
                      if (!_isSerial) {
                        _portController.text = _type == ConnectionType.ssh
                            ? '${AppConstants.defaultSshPort}'
                            : '${AppConstants.defaultTelnetPort}';
                      }
                    });
                  },
                )
              else
                Text(
                  '类型:${_device!.type.displayName}'
                  '(移动端暂不支持连接,仅可编辑信息)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _folder,
                decoration: const InputDecoration(
                  labelText: '所在文件夹',
                  hintText: '不选则为根目录',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('根目录')),
                  for (final folder
                      in context.watch<DeviceController>().folders)
                    DropdownMenuItem(value: folder, child: Text(folder)),
                ],
                onChanged: (value) => setState(() => _folder = value ?? ''),
              ),
              const SizedBox(height: 8),
              if (_isSerial)
                SerialPortField(controller: _hostController)
              else
                TextFormField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: '主机地址',
                    hintText: '如 192.168.0.1',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? '请输入主机地址'
                      : null,
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '设备用途说明(可选)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tagController,
                decoration: const InputDecoration(
                  labelText: '标签',
                  hintText: '如:生产/测试/办公(每台一个)',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
              if (_isSerial) ...[
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: '$_baudRate',
                  decoration: const InputDecoration(
                    labelText: '波特率',
                    prefixIcon: Icon(Icons.speed),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      int.tryParse(value ?? '') == null ? '波特率无效' : null,
                  onChanged: (value) =>
                      _baudRate = int.tryParse(value) ?? _baudRate,
                ),
              ] else ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: '端口',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final port = int.tryParse(value ?? '');
                    if (port == null || port <= 0 || port > 65535) {
                      return '端口无效';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 8),
                if (_type == ConnectionType.ssh) ...[
                  SegmentedButton<AuthMethod>(
                    segments: [
                      for (final method in AuthMethod.values)
                        ButtonSegment(
                          value: method,
                          label: Text(method.displayName),
                        ),
                    ],
                    selected: {_authMethod},
                    onSelectionChanged: (selection) {
                      setState(() => _authMethod = selection.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_authMethod == AuthMethod.password)
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                    )
                  else
                    _KeySelectSection(
                      keyName: _selectedKeyName,
                      onSelect: _pickKey,
                      onImport: _importKey,
                    ),
                ] else
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? '保存修改' : '保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 弹出全局密钥库选择面板,选中后记录密钥信息。
  Future<void> _pickKey() async {
    final key = await showModalBottomSheet<StoredKey>(
      context: context,
      builder: (context) => const SshKeyPickerSheet(),
    );
    if (key == null || !mounted) {
      return;
    }
    setState(() {
      _selectedKeyPath = key.filePath;
      _selectedKeyName = key.name;
      _selectedKeyPrivateKey = key.privateKey;
      _selectedKeyPassphrase = key.passphrase;
    });
  }

  /// 弹出导入面板:粘贴 PEM 或选择文件,校验通过后入库并选中。
  Future<void> _importKey() async {
    final key = await showDialog<StoredKey>(
      context: context,
      builder: (context) => const _ImportKeyDialog(),
    );
    if (key == null || !mounted) {
      return;
    }
    setState(() {
      _selectedKeyPath = key.filePath;
      _selectedKeyName = key.name;
      _selectedKeyPrivateKey = key.privateKey;
      _selectedKeyPassphrase = key.passphrase;
    });
  }

  /// 从密钥文件路径提取密钥名(文件名去掉 .json)。
  static String _keyNameFromPath(String path) {
    if (path.isEmpty) {
      return '';
    }
    final file = path.split(Platform.pathSeparator).last;
    return file.endsWith('.json')
        ? file.substring(0, file.length - '.json'.length)
        : file;
  }

  /// 校验并保存设备。
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // 不支持类型的编辑沿用原认证方式与密钥引用(如 sftp 私钥认证),
    // 避免保存后配置丢失;新建不可能是不支持类型。
    final authMethod = _isSerial
        ? AuthMethod.password
        : _type == ConnectionType.ssh
        ? _authMethod
        : (_device?.authMethod ?? AuthMethod.password);
    final usesKey = !_isSerial && authMethod == AuthMethod.privateKey;
    final device = Device(
      name: _nameController.text.trim(),
      type: _type,
      host: _hostController.text.trim(),
      port: _isSerial ? 0 : (int.tryParse(_portController.text) ?? 0),
      username: _isSerial ? '' : _usernameController.text.trim(),
      password: usesKey ? '' : _passwordController.text,
      authMethod: authMethod,
      privateKey: usesKey ? _selectedKeyPrivateKey : '',
      privateKeyPassphrase: usesKey ? _selectedKeyPassphrase : '',
      hostKey: _device?.hostKey ?? '',
      baudRate: _isSerial ? _baudRate : AppConstants.defaultSerialBaudRate,
      note: _noteController.text.trim(),
      tag: _tagController.text.trim(),
      openCount: _device?.openCount ?? 0,
      lastConnectedAt: _device?.lastConnectedAt,
      createdAt: _device?.createdAt ?? now,
      updatedAt: now,
      folder: _folder,
      keyPath: usesKey ? _selectedKeyPath : '',
    );
    try {
      final controller = context.read<DeviceController>();
      if (_isEditing) {
        // 编辑时传入原名与原文件夹,会话名/文件夹修改后仓库会迁移文件。
        await controller.updateDevice(
          device,
          previousName: _device!.name,
          previousFolder: _device!.folder,
        );
      } else {
        await controller.addDevice(device);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('保存设备失败', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败:$error')));
      }
    }
  }
}

/// 密钥选择区:展示当前选中密钥,提供「选择密钥」与「导入密钥」入口。
class _KeySelectSection extends StatelessWidget {
  /// 创建密钥选择区。
  const _KeySelectSection({
    required this.keyName,
    required this.onSelect,
    required this.onImport,
  });

  /// 已选密钥名(空表示未选择)。
  final String keyName;

  /// 选择密钥回调。
  final VoidCallback onSelect;

  /// 导入密钥回调。
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = keyName.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.vpn_key_outlined,
            color: selected ? scheme.primary : scheme.outline,
          ),
          title: Text(
            selected ? keyName : '未选择密钥',
            style: TextStyle(color: selected ? null : scheme.outline),
          ),
          subtitle: Text(selected ? '密钥库中的密钥' : '请选择或导入一个密钥'),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.key, size: 18),
                label: const Text('选择密钥'),
                onPressed: onSelect,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('导入密钥'),
                onPressed: onImport,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 导入密钥对话框:粘贴 PEM 或选择文件,加密密钥需输入口令。
class _ImportKeyDialog extends StatefulWidget {
  /// 创建导入密钥对话框。
  const _ImportKeyDialog();

  @override
  State<_ImportKeyDialog> createState() => _ImportKeyDialogState();
}

class _ImportKeyDialogState extends State<_ImportKeyDialog> {
  final _pemController = TextEditingController();
  final _passphraseController = TextEditingController();
  String? _errorText;
  bool _importing = false;

  @override
  void dispose() {
    _pemController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入密钥'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _pemController,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'OpenSSH 私钥(PEM)',
                hintText: '粘贴私钥内容或选择文件',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('选择私钥文件'),
              onPressed: _pickFile,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passphraseController,
              decoration: const InputDecoration(
                labelText: '私钥口令',
                hintText: '加密私钥才需要填写',
                prefixIcon: Icon(Icons.password),
              ),
              obscureText: true,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _importing ? null : _import,
          child: Text(_importing ? '导入中' : '导入'),
        ),
      ],
    );
  }

  /// 从文件选择器读取 PEM 文本。
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        dialogTitle: '选择私钥文件',
      );
      final path = result?.files.single.path;
      if (path == null) {
        return;
      }
      final content = await File(path).readAsString();
      if (mounted) {
        setState(() => _pemController.text = content.trim());
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('读取私钥文件失败', error, stackTrace);
      if (mounted) {
        setState(() => _errorText = '读取文件失败:$error');
      }
    }
  }

  /// 校验并入库密钥,成功时返回密钥记录。
  Future<void> _import() async {
    final pem = _pemController.text.trim();
    final passphrase = _passphraseController.text;
    if (!pem.contains('-----BEGIN')) {
      setState(() => _errorText = '文件内容不是 PEM 私钥');
      return;
    }
    // 加密私钥必须提供正确口令;非加密私钥校验可解析性。
    if (SshKeyService.isEncryptedPem(pem)) {
      if (passphrase.isEmpty) {
        setState(() => _errorText = '加密私钥需要填写口令');
        return;
      }
      if (!SshKeyService.isValidPemWithPassphrase(pem, passphrase)) {
        setState(() => _errorText = '私钥口令错误或格式无效');
        return;
      }
    } else if (!SshKeyService.isValidPem(pem)) {
      setState(() => _errorText = '私钥格式无效,请使用 OpenSSH 格式');
      return;
    }
    setState(() {
      _errorText = null;
      _importing = true;
    });
    try {
      final key = await SshKeyRepository().createKey(
        privateKey: pem,
        passphrase: passphrase,
      );
      if (mounted) {
        Navigator.of(context).pop(key);
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('导入密钥失败', error, stackTrace);
      if (mounted) {
        setState(() {
          _errorText = '导入失败:$error';
          _importing = false;
        });
      }
    }
  }
}
