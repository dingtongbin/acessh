// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../../connection/application/ssh_key_service.dart';
import '../application/device_controller.dart';
import '../domain/auth_method.dart';
import '../domain/connection_type.dart';
import '../domain/device.dart';
import 'serial_port_field.dart';

/// 新建/编辑设备底部弹窗,支持密码与私钥认证,私钥可导入或生成。
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
  late final TextEditingController _privateKeyController;
  late final TextEditingController _privateKeyPassphraseController;
  late final TextEditingController _noteController;
  late final TextEditingController _tagController;
  late ConnectionType _type;
  late AuthMethod _authMethod;
  late int _baudRate;
  bool _generatingKey = false;

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
    _privateKeyController = TextEditingController(
      text: device?.privateKey ?? '',
    );
    _privateKeyPassphraseController = TextEditingController(
      text: device?.privateKeyPassphrase ?? '',
    );
    _noteController = TextEditingController(text: device?.note ?? '');
    _tagController = TextEditingController(text: device?.tag ?? '');
    _type = device?.type ?? ConnectionType.ssh;
    _authMethod = device?.authMethod ?? AuthMethod.password;
    _baudRate = device?.baudRate ?? AppConstants.defaultSerialBaudRate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _privateKeyPassphraseController.dispose();
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
              SegmentedButton<ConnectionType>(
                segments: [
                  for (final type in ConnectionType.values)
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
                    _PrivateKeySection(
                      controller: _privateKeyController,
                      passphraseController: _privateKeyPassphraseController,
                      generating: _generatingKey,
                      onImport: _importPrivateKey,
                      onGenerate: _generatePrivateKey,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入私钥';
                        }
                        if (!SshKeyService.isValidPem(value)) {
                          return '私钥格式无效,请使用 OpenSSH 格式';
                        }
                        return null;
                      },
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

  /// 从文件选择器导入 OpenSSH 私钥文本。
  Future<void> _importPrivateKey() async {
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
      if (!content.contains('-----BEGIN')) {
        throw const FormatException('文件内容不是 PEM 私钥');
      }
      if (!mounted) {
        return;
      }
      setState(() => _privateKeyController.text = content.trim());
    } on Object catch (error, stackTrace) {
      AppLogger.e('导入私钥失败', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入私钥失败:$error')));
      }
    }
  }

  /// 生成一对新的 Ed25519 密钥并填入私钥输入框。
  Future<void> _generatePrivateKey() async {
    setState(() => _generatingKey = true);
    try {
      final pem = await SshKeyService.generateEd25519();
      if (mounted) {
        setState(() => _privateKeyController.text = pem);
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('生成私钥失败', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('生成私钥失败:$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _generatingKey = false);
      }
    }
  }

  /// 校验并保存设备。
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final device = Device(
      name: _nameController.text.trim(),
      type: _type,
      host: _hostController.text.trim(),
      port: _isSerial ? 0 : (int.tryParse(_portController.text) ?? 0),
      username: _isSerial ? '' : _usernameController.text.trim(),
      password: _isSerial
          ? ''
          : (_authMethod == AuthMethod.password
                ? _passwordController.text
                : ''),
      authMethod: _isSerial
          ? AuthMethod.password
          : (_type == ConnectionType.ssh ? _authMethod : AuthMethod.password),
      privateKey: _isSerial || _authMethod != AuthMethod.privateKey
          ? ''
          : _privateKeyController.text.trim(),
      privateKeyPassphrase: _isSerial || _authMethod != AuthMethod.privateKey
          ? ''
          : _privateKeyPassphraseController.text,
      hostKey: _device?.hostKey ?? '',
      baudRate: _isSerial ? _baudRate : AppConstants.defaultSerialBaudRate,
      note: _noteController.text.trim(),
      tag: _tagController.text.trim(),
      openCount: _device?.openCount ?? 0,
      lastConnectedAt: _device?.lastConnectedAt,
      createdAt: _device?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      final controller = context.read<DeviceController>();
      if (_isEditing) {
        await controller.updateDevice(device);
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

/// 私钥输入区域:文本输入 + 口令输入 + 导入文件 + 生成密钥按钮。
class _PrivateKeySection extends StatelessWidget {
  /// 创建私钥输入区域。
  const _PrivateKeySection({
    required this.controller,
    required this.passphraseController,
    required this.generating,
    required this.onImport,
    required this.onGenerate,
    required this.validator,
  });

  /// 私钥文本控制器。
  final TextEditingController controller;

  /// 私钥口令控制器(仅加密私钥需要)。
  final TextEditingController passphraseController;

  /// 是否正在生成密钥。
  final bool generating;

  /// 导入文件回调。
  final VoidCallback onImport;

  /// 生成密钥回调。
  final VoidCallback onGenerate;

  /// 文本校验器。
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          maxLines: 6,
          minLines: 3,
          decoration: const InputDecoration(
            labelText: 'OpenSSH 私钥(PEM)',
            prefixIcon: Icon(Icons.key),
            alignLabelWithHint: true,
          ),
          validator: validator,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: passphraseController,
          decoration: const InputDecoration(
            labelText: '私钥口令',
            hintText: '加密私钥的密码(非加密私钥留空)',
            prefixIcon: Icon(Icons.password),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('导入'),
                onPressed: onImport,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                icon: generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high, size: 18),
                label: Text(generating ? '生成中' : '生成密钥'),
                onPressed: generating ? null : onGenerate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
