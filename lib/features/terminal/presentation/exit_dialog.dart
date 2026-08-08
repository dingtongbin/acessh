// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../../settings/application/app_settings.dart';

/// 退出对话框返回结果。
class ExitDialogResult {
  /// 创建退出结果。
  const ExitDialogResult({required this.action, required this.remember});

  /// 选择的退出动作。
  final ExitAction action;

  /// 是否记住本次操作。
  final bool remember;
}

/// 退出会话确认对话框:选择关闭连接退出或后台挂起退出,可记住本次操作。
class ExitDialog extends StatefulWidget {
  /// 创建退出确认对话框。
  const ExitDialog({
    required this.initialAction,
    required this.initialRemember,
    super.key,
  });

  /// 初始选中的动作。
  final ExitAction initialAction;

  /// 初始是否记住。
  final bool initialRemember;

  @override
  State<ExitDialog> createState() => _ExitDialogState();
}

class _ExitDialogState extends State<ExitDialog> {
  late ExitAction _action;
  late bool _remember;

  @override
  void initState() {
    super.initState();
    _action = widget.initialAction;
    _remember = widget.initialRemember;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('退出会话'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<ExitAction>(
            groupValue: _action,
            onChanged: (value) {
              if (value != null) {
                setState(() => _action = value);
              }
            },
            child: Column(
              children: [
                const RadioListTile<ExitAction>(
                  title: Text('关闭连接退出'),
                  subtitle: Text('断开连接并结束会话'),
                  value: ExitAction.close,
                ),
                const RadioListTile<ExitAction>(
                  title: Text('后台挂起退出'),
                  subtitle: Text('保持连接,可在"已连接"中切回'),
                  value: ExitAction.background,
                ),
              ],
            ),
          ),
          CheckboxListTile(
            title: const Text('记住本次操作'),
            subtitle: const Text('下次退出直接按此动作执行'),
            value: _remember,
            onChanged: (value) {
              setState(() => _remember = value ?? false);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(ExitDialogResult(action: _action, remember: _remember)),
          child: const Text('退出'),
        ),
      ],
    );
  }
}
