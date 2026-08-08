// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

/// 脚本/文件夹名称输入对话框(新建与重命名共用)。
class ScriptNameDialog extends StatefulWidget {
  /// 创建名称输入对话框。
  const ScriptNameDialog({
    required this.title,
    required this.label,
    this.initialValue = '',
    super.key,
  });

  /// 对话框标题。
  final String title;

  /// 输入框标签。
  final String label;

  /// 初始值(重命名时使用)。
  final String initialValue;

  @override
  State<ScriptNameDialog> createState() => _ScriptNameDialogState();
}

class _ScriptNameDialogState extends State<ScriptNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('确定')),
      ],
    );
  }

  /// 校验并返回名称。
  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名称不能为空')));
      return;
    }
    Navigator.of(context).pop(name);
  }
}
