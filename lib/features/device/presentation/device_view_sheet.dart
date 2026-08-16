// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../settings/application/app_settings.dart';
import '../../settings/presentation/app_lock_screen.dart';
import '../../settings/presentation/app_lock_settings_screen.dart';
import '../application/device_controller.dart';
import '../domain/connection_type.dart';
import '../domain/device.dart';

/// 设备查看弹出层:只读信息展示。
///
/// 密码默认以 **** 脱敏,点击眼睛图标需通过应用锁验证才能查看明文;
/// 未设置应用锁时引导跳转应用锁设置页。SSH 指纹可在此查看与删除。
class DeviceViewSheet extends StatefulWidget {
  /// 创建设备查看弹出层。
  const DeviceViewSheet({required this.device, super.key});

  /// 设备数据。
  final Device device;

  @override
  State<DeviceViewSheet> createState() => _DeviceViewSheetState();
}

class _DeviceViewSheetState extends State<DeviceViewSheet> {
  /// 是否已通过应用锁验证可查看密码明文。
  bool _passwordVisible = false;

  Device get device => widget.device;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSsh = device.type == ConnectionType.ssh;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(device.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${device.type.displayName} · '
              '打开 ${device.openCount} 次 · '
              '最近 ${DateFormatter.formatMillis(device.lastConnectedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            _InfoRow(label: '类型', value: device.type.displayName),
            if (!device.isSupportedOnMobile) ...[
              const SizedBox(height: 4),
              Text(
                '移动端暂不支持该类型连接,仅可查看与编辑',
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ],
            if (device.type == ConnectionType.serial) ...[
              _InfoRow(label: '串口设备', value: device.host),
              _InfoRow(label: '波特率', value: '${device.baudRate}'),
            ] else ...[
              _InfoRow(label: '主机', value: device.host),
              _InfoRow(label: '端口', value: '${device.port}'),
            ],
            if (!isSsh) _InfoRow(label: '用户名', value: device.username),
            if (device.type == ConnectionType.telnet ||
                !device.type.isSupportedOnMobile)
              _buildPasswordRow(context)
            else if (isSsh) ...[
              _InfoRow(label: '认证方式', value: device.authMethod.displayName),
              if (device.usesPrivateKey) ...[
                _InfoRow(
                  label: '私钥',
                  value: device.privateKey.isNotEmpty
                      ? '已配置(${device.privateKey.length} 字符)'
                      : '未配置',
                ),
                if (device.privateKeyPassphrase.isNotEmpty)
                  _InfoRow(label: '私钥口令', value: '已配置'),
              ] else
                _buildPasswordRow(context),
            ],
            if (device.note.isNotEmpty)
              _InfoRow(label: '备注', value: device.note),
            if (isSsh) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '主机指纹',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          device.hostKey.isEmpty ? '未保存' : device.hostKey,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.outline),
                        ),
                      ],
                    ),
                  ),
                  if (device.hostKey.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: '删除指纹',
                      onPressed: () => _deleteHostKey(context),
                    ),
                ],
              ),
            ],
            const Divider(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  /// 密码行(脱敏 + 眼睛图标)。
  Widget _buildPasswordRow(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: _InfoRow(label: '密码', value: '****'),
        ),
        IconButton(
          icon: Icon(
            _passwordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
          tooltip: _passwordVisible ? '隐藏密码' : '查看密码',
          onPressed: () async {
            if (_passwordVisible) {
              setState(() => _passwordVisible = false);
              return;
            }
            await _verifyForPassword(context);
          },
        ),
      ],
    );
  }

  /// 查看密码前验证应用锁;未设置时引导设置。
  Future<void> _verifyForPassword(BuildContext context) async {
    final settings = context.read<AppSettings>();
    if (!settings.appLockEnabled || !settings.hasAppLockCredential) {
      final goSetup = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('未设置应用锁'),
          content: const Text('查看密码需要开启应用锁,是否前往设置?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('前往设置'),
            ),
          ],
        ),
      );
      if (goSetup == true && context.mounted) {
        Navigator.of(context).pop(); // 关闭查看层。
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const AppLockSettingsScreen(),
          ),
        );
      }
      return;
    }
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('验证身份'),
        content: AppLockScreen(
          onUnlocked: () => Navigator.of(context).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (verified == true && mounted) {
      setState(() => _passwordVisible = true);
    }
  }

  /// 删除主机指纹(同时关闭同名会话,避免已信任连接继续)。
  Future<void> _deleteHostKey(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除主机指纹'),
        content: const Text('删除后下次连接将重新要求确认。'),
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
    final controller = context.read<DeviceController>();
    await controller.clearHostKey(device.name, folder: device.folder);
  }
}

/// 只读信息行。
class _InfoRow extends StatelessWidget {
  /// 创建信息行。
  const _InfoRow({required this.label, required this.value});

  /// 字段名。
  final String label;

  /// 字段值。
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
