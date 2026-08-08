// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../../script/domain/app_script.dart';

/// 脚本执行确认弹窗:预览脚本内容,确认后才会执行。
class ScriptExecuteConfirmDialog extends StatelessWidget {
  /// 创建脚本执行确认弹窗。
  const ScriptExecuteConfirmDialog({required this.script, super.key});

  /// 待执行的脚本。
  final AppScript script;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('执行脚本"${script.name}"?'),
      content: SingleChildScrollView(
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            script.content,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('确认执行'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
