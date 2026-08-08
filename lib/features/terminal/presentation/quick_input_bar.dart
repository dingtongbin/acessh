// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kterm/kterm.dart';
import 'package:provider/provider.dart';

import '../../../core/logging/app_logger.dart';
import '../application/input_modifier_controller.dart';

/// 快捷栏单个键位定义。
class QuickKey {
  /// 创建键位定义。
  const QuickKey(this.label, this.key, {this.ctrl = false});

  /// 按钮显示文本。
  final String label;

  /// 对应的终端键位。
  final TerminalKey key;

  /// 是否带 Ctrl 修饰。
  final bool ctrl;
}

/// 手机端快捷输入栏:两排按键 + Fn 模式(F1-F12 两行),
/// Ctrl/Alt 支持修饰锁定组合(与系统键盘输入同样生效),右下角为系统键盘开关。
class QuickInputBar extends StatelessWidget {
  /// 创建快捷输入栏。
  const QuickInputBar({
    required this.terminal,
    required this.focusNode,
    required this.keyboardEnabled,
    required this.onKeyboardToggle,
    super.key,
  });

  /// kterm 终端实例。
  final Terminal terminal;

  /// 终端焦点节点,用于拉起/关闭系统键盘。
  final FocusNode focusNode;

  /// 系统键盘允许状态(由终端页统一管理)。
  final ValueListenable<bool> keyboardEnabled;

  /// 切换系统键盘回调(由终端页统一处理)。
  final VoidCallback onKeyboardToggle;

  /// 第一排:ESC / | - home ↑ end pgup fn。
  static const List<QuickKey> _rowOne = [
    QuickKey('ESC', TerminalKey.escape),
    QuickKey('/', TerminalKey.slash),
    QuickKey('|', TerminalKey.backslash),
    QuickKey('-', TerminalKey.minus),
    QuickKey('Home', TerminalKey.home),
    QuickKey('↑', TerminalKey.arrowUp),
    QuickKey('End', TerminalKey.end),
    QuickKey('PgUp', TerminalKey.pageUp),
  ];

  /// 第二排:tab ctrl alt ← → ↓ pgdn(键盘开关在末尾)。
  ///
  /// ↓ 位于第 6 列,与第一排的 ↑ 垂直对齐。
  static const List<QuickKey> _rowTwo = [
    QuickKey('Tab', TerminalKey.tab),
    QuickKey('←', TerminalKey.arrowLeft),
    QuickKey('→', TerminalKey.arrowRight),
    QuickKey('↓', TerminalKey.arrowDown),
    QuickKey('PgDn', TerminalKey.pageDown),
  ];

  /// Fn 模式第一排:F1-F6。
  static const List<QuickKey> _fnRowOne = [
    QuickKey('F1', TerminalKey.f1),
    QuickKey('F2', TerminalKey.f2),
    QuickKey('F3', TerminalKey.f3),
    QuickKey('F4', TerminalKey.f4),
    QuickKey('F5', TerminalKey.f5),
    QuickKey('F6', TerminalKey.f6),
  ];

  /// Fn 模式第二排:F7-F12。
  static const List<QuickKey> _fnRowTwo = [
    QuickKey('F7', TerminalKey.f7),
    QuickKey('F8', TerminalKey.f8),
    QuickKey('F9', TerminalKey.f9),
    QuickKey('F10', TerminalKey.f10),
    QuickKey('F11', TerminalKey.f11),
    QuickKey('F12', TerminalKey.f12),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isFnMode(context)) ...[
                // Fn 模式:第一排 6 个 F 键 + 返回(退出 Fn 模式)。
                _buildFnRow(context, _fnRowOne, rightIsExitFn: true),
                const SizedBox(height: 4),
                // 第二排 6 个 F 键 + 键盘开关。
                _buildFnRow(context, _fnRowTwo, rightIsExitFn: false),
              ] else ...[
                _buildRowOne(context),
                const SizedBox(height: 4),
                _buildRowTwo(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 是否处于 Fn 模式。
  bool _isFnMode(BuildContext context) {
    return context.select<InputModifierController, bool>(
      (controller) => controller.fnMode,
    );
  }

  /// 第一排:普通键 + Fn 切换。
  Widget _buildRowOne(BuildContext context) {
    return Row(
      children: [
        for (final key in _rowOne)
          _QuickKeyButton(quickKey: key, onPressed: () => _sendKey(key)),
        _FnToggleButton(),
      ],
    );
  }

  /// 第二排:修饰键 + 方向键 + 键盘开关。
  Widget _buildRowTwo(BuildContext context) {
    return Row(
      children: [
        _ModifierKey(
          label: 'Ctrl',
          active: context.select<InputModifierController, bool>(
            (controller) => controller.ctrlLocked,
          ),
          onPressed: () {
            final controller = InputModifierController.instance;
            controller.setCtrlLocked(!controller.ctrlLocked);
          },
        ),
        _ModifierKey(
          label: 'Alt',
          active: context.select<InputModifierController, bool>(
            (controller) => controller.altLocked,
          ),
          onPressed: () {
            final controller = InputModifierController.instance;
            controller.setAltLocked(!controller.altLocked);
          },
        ),
        for (final key in _rowTwo)
          _QuickKeyButton(quickKey: key, onPressed: () => _sendKey(key)),
        _KeyboardToggleButton(
          enabled: keyboardEnabled,
          onPressed: onKeyboardToggle,
        ),
      ],
    );
  }

  /// Fn 模式行:六个 F 键 + 右侧按钮。
  ///
  /// [rightIsExitFn] 为真时右侧为"返回"(退出 Fn 模式),
  /// 否则为系统键盘开关。
  Widget _buildFnRow(
    BuildContext context,
    List<QuickKey> keys, {
    required bool rightIsExitFn,
  }) {
    return Row(
      children: [
        for (final key in keys)
          _QuickKeyButton(quickKey: key, onPressed: () => _sendKey(key)),
        if (rightIsExitFn)
          _QuickKeyButton(
            quickKey: const QuickKey('返回', TerminalKey.none),
            onPressed: () {
              final controller = InputModifierController.instance;
              controller.setFnMode(false);
            },
          )
        else
          _KeyboardToggleButton(
            enabled: keyboardEnabled,
            onPressed: onKeyboardToggle,
          ),
      ],
    );
  }

  /// 发送键位,修饰键锁定状态随发送自动解除。
  void _sendKey(QuickKey quickKey) {
    final controller = InputModifierController.instance;
    try {
      terminal.keyInput(
        quickKey.key,
        ctrl: controller.ctrlLocked || quickKey.ctrl,
        alt: controller.altLocked,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('快捷栏发送按键失败', error, stackTrace);
    }
    controller.reset();
  }
}

/// 修饰键按钮(Ctrl/Alt 锁定开关)。
class _ModifierKey extends StatelessWidget {
  /// 创建修饰键按钮。
  const _ModifierKey({
    required this.label,
    required this.active,
    required this.onPressed,
  });

  /// 按钮文本。
  final String label;

  /// 是否处于锁定状态。
  final bool active;

  /// 点击回调。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final longLabel = label.runes.length > 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: longLabel ? 10 : 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 普通快捷按键:固定方块大小,长文本使用小字号且不加内边距。
class _QuickKeyButton extends StatelessWidget {
  /// 创建快捷按键。
  const _QuickKeyButton({required this.quickKey, required this.onPressed});

  /// 键位定义。
  final QuickKey quickKey;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 键宽(窄尺寸,保证 9 键放得下)。
  static const double _width = 36;

  /// 键高。
  static const double _height = 36;

  /// 长文本使用的小字号。
  static const double _smallFontSize = 9;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 超过 2 个字符的文本(如 Home/PgUp/返回)缩小字号,
    // 且不再占用水平内边距,保证完整显示。
    final longLabel = quickKey.label.runes.length > 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: SizedBox(
            width: _width,
            height: _height,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  quickKey.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: longLabel ? _smallFontSize : 12,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fn 模式切换按钮(主键盘第一排)。
class _FnToggleButton extends StatelessWidget {
  /// 创建 Fn 切换按钮。
  const _FnToggleButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = context.select<InputModifierController, bool>(
      (controller) => controller.fnMode,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            final controller = InputModifierController.instance;
            controller.setFnMode(!controller.fnMode);
          },
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Text(
                'FN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 键盘开关按钮:拉起或关闭系统键盘(状态由终端页统一管理)。
class _KeyboardToggleButton extends StatelessWidget {
  /// 创建键盘开关按钮。
  const _KeyboardToggleButton({required this.enabled, required this.onPressed});

  /// 键盘允许状态。
  final ValueListenable<bool> enabled;

  /// 点击回调。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (context, value, _) => Center(
                child: Icon(
                  value
                      ? Icons.keyboard_hide_outlined
                      : Icons.keyboard_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
