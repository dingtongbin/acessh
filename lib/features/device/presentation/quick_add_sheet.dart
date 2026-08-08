// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../application/device_controller.dart';
import '../domain/auth_method.dart';
import '../domain/connection_type.dart';
import '../domain/device.dart';
import 'serial_port_field.dart';

/// 快速添加设备底部弹出层:仅支持密码认证(SSH/Telnet/串口)。
class QuickAddSheet extends StatefulWidget {
  /// 创建快速添加设备弹出层。
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagController = TextEditingController();
  ConnectionType _type = ConnectionType.ssh;
  int _baudRate = AppConstants.defaultSerialBaudRate;

  @override
  void initState() {
    super.initState();
    _portController.text = '${AppConstants.defaultSshPort}';
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
    final isSerial = _type == ConnectionType.serial;
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
              Text('快速添加设备', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SegmentedButton<ConnectionType>(
                segments: [
                  for (final type in ConnectionType.values)
                    ButtonSegment(value: type, label: Text(type.displayName)),
                ],
                selected: {_type},
                onSelectionChanged: (selection) {
                  setState(() => _type = selection.first);
                  if (!isSerial) {
                    _portController.text = selection.first == ConnectionType.ssh
                        ? '${AppConstants.defaultSshPort}'
                        : '${AppConstants.defaultTelnetPort}';
                  }
                },
              ),
              const SizedBox(height: 8),
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
              if (isSerial)
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
              if (isSerial) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _baudRate,
                  decoration: const InputDecoration(
                    labelText: '波特率',
                    prefixIcon: Icon(Icons.speed),
                  ),
                  items: const [
                    DropdownMenuItem(value: 9600, child: Text('9600')),
                    DropdownMenuItem(value: 19200, child: Text('19200')),
                    DropdownMenuItem(value: 38400, child: Text('38400')),
                    DropdownMenuItem(value: 57600, child: Text('57600')),
                    DropdownMenuItem(value: 115200, child: Text('115200')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _baudRate = value);
                    }
                  },
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
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) =>
                      (value == null || value.isEmpty) ? '请输入密码' : null,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('保存')),
            ],
          ),
        ),
      ),
    );
  }

  /// 校验并保存设备(仅密码认证)。
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final isSerial = _type == ConnectionType.serial;
    final device = Device(
      name: _nameController.text.trim(),
      type: _type,
      host: _hostController.text.trim(),
      port: isSerial ? 0 : (int.tryParse(_portController.text) ?? 0),
      username: isSerial ? '' : _usernameController.text.trim(),
      password: isSerial ? '' : _passwordController.text,
      authMethod: AuthMethod.password,
      privateKey: '',
      privateKeyPassphrase: '',
      hostKey: '',
      baudRate: isSerial ? _baudRate : AppConstants.defaultSerialBaudRate,
      note: _noteController.text.trim(),
      tag: _tagController.text.trim(),
      openCount: 0,
      lastConnectedAt: null,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await context.read<DeviceController>().addDevice(device);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('快速添加设备失败', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败:$error')));
      }
    }
  }
}
