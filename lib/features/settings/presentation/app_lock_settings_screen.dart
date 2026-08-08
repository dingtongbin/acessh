// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/app_settings.dart';
import 'app_lock_screen.dart';
import 'pattern_lock.dart';

/// 应用锁设置页:开关、设置密码/图案、更改凭据与查看密码。
class AppLockSettingsScreen extends StatefulWidget {
  /// 创建应用锁设置页。
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('应用锁设置')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('启用应用锁'),
            subtitle: const Text('启动应用时需要验证才能进入'),
            value: settings.appLockEnabled,
            onChanged: (value) {
              if (value) {
                _setupLock(context);
              } else {
                _disableLockWithVerify(context);
              }
            },
          ),
          if (settings.appLockEnabled) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('解锁方式'),
              subtitle: Text(settings.appLockMode == 'pin' ? '数字密码' : '图案'),
            ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('更改解锁方式'),
              onTap: () => _setupLock(context, changeMode: true),
            ),
            ListTile(
              leading: const Icon(Icons.lock_open_outlined),
              title: const Text('关闭应用锁'),
              onTap: () => _disableLockWithVerify(context),
            ),
          ],
        ],
      ),
    );
  }

  /// 关闭应用锁前先验证当前锁。
  Future<void> _disableLockWithVerify(BuildContext context) async {
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
    if (verified == true && context.mounted) {
      await context.read<AppSettings>().disableAppLock();
    }
  }

  /// 进入设置流程:选择模式 → 设置凭据(两次确认)。
  Future<void> _setupLock(
    BuildContext context, {
    bool changeMode = false,
  }) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择解锁方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('数字密码'),
              onTap: () => Navigator.of(context).pop('pin'),
            ),
            ListTile(
              leading: const Icon(Icons.gesture),
              title: const Text('图案'),
              onTap: () => Navigator.of(context).pop('pattern'),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !context.mounted) {
      return;
    }
    final settings = context.read<AppSettings>();
    if (mode == 'pin') {
      final pin = await _setupPin(context);
      if (pin != null && context.mounted) {
        await settings.setAppLock(enabled: true, mode: 'pin', pin: pin);
      }
    } else {
      final pattern = await _setupPattern(context);
      if (pattern != null && context.mounted) {
        await settings.setAppLock(
          enabled: true,
          mode: 'pattern',
          pattern: pattern.join(','),
        );
      }
    }
  }

  /// 设置数字密码:两次输入一致才返回。
  Future<String?> _setupPin(BuildContext context) {
    final firstController = TextEditingController();
    final secondController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('设置数字密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: '输入密码',
                  counterText: '',
                ),
              ),
              TextField(
                controller: secondController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: '再次输入密码',
                  counterText: '',
                ),
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
                final first = firstController.text.trim();
                final second = secondController.text.trim();
                if (first.isEmpty || first.length < 4) {
                  _toast('密码至少 4 位');
                  return;
                }
                if (first != second) {
                  _toast('两次输入不一致');
                  return;
                }
                Navigator.of(context).pop(first);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  /// 设置图案:绘制两次一致才返回。
  Future<List<int>?> _setupPattern(BuildContext context) {
    List<int>? firstPattern;
    return showDialog<List<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(firstPattern == null ? '绘制解锁图案' : '再次绘制确认图案'),
          content: PatternLock(
            size: 240,
            onCompleted: (pattern) {
              if (pattern.length < 4) {
                _toast('至少连接 4 个点');
                return;
              }
              if (firstPattern == null) {
                firstPattern = pattern;
                setDialogState(() {});
              } else if (_samePattern(firstPattern!, pattern)) {
                Navigator.of(context).pop(pattern);
              } else {
                _toast('两次绘制不一致,请重新设置');
                firstPattern = null;
                setDialogState(() {});
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  /// 图案是否一致。
  static bool _samePattern(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  /// 提示消息。
  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
