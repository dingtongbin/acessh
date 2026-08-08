// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../application/app_settings.dart';
import 'pattern_lock.dart';

/// 应用锁验证页:启动或查看凭据时要求正确输入密码/图案。
class AppLockScreen extends StatefulWidget {
  /// 创建应用锁页。
  const AppLockScreen({this.onUnlocked, super.key});

  /// 验证成功回调(为空时验证成功后由外部负责跳转)。
  final VoidCallback? onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _pinError;
  List<int>? _patternError;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final mode = settings.appLockMode;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  mode == 'pin' ? '请输入应用锁密码' : '请绘制解锁图案',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                if (mode == 'pin')
                  _buildPinInput(context)
                else
                  _buildPatternInput(context),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('退出应用'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 密码输入区(数字键盘)。
  Widget _buildPinInput(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            controller: _pinController,
            obscureText: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 8,
            autofocus: true,
            style: const TextStyle(fontSize: 24, letterSpacing: 12),
            decoration: InputDecoration(
              counterText: '',
              errorText: _pinError,
              hintText: '••••',
            ),
            onSubmitted: (_) => _verifyPin(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _verifyPin, child: const Text('解锁')),
      ],
    );
  }

  /// 图案输入区。
  Widget _buildPatternInput(BuildContext context) {
    return PatternLock(
      errorPattern: _patternError,
      onCompleted: _verifyPattern,
    );
  }

  /// 校验密码。
  void _verifyPin() {
    final settings = context.read<AppSettings>();
    final input = _pinController.text.trim();
    if (input != settings.appLockPin) {
      setState(() => _pinError = '密码错误,请重试');
      return;
    }
    _pinController.clear();
    _onUnlocked();
  }

  /// 校验图案。
  void _verifyPattern(List<int> pattern) {
    final settings = context.read<AppSettings>();
    final stored = _decodePattern(settings.appLockPattern);
    if (pattern.length < 4 || !_samePattern(pattern, stored)) {
      setState(() => _patternError = pattern);
      // 短暂显示错误后清空,便于重试。
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() => _patternError = null);
        }
      });
      return;
    }
    _onUnlocked();
  }

  /// 解锁成功回调。
  void _onUnlocked() {
    widget.onUnlocked?.call();
  }

  /// 解析存储的图案序号列表。
  static List<int> _decodePattern(String stored) {
    if (stored.isEmpty) {
      return const [];
    }
    return stored.split(',').map(int.parse).toList();
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
}
