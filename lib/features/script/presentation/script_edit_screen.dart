// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/bash.dart';
import 'package:provider/provider.dart';

import '../../../core/logging/app_logger.dart';
import '../application/script_controller.dart';
import '../domain/app_script.dart';

/// 脚本编辑独立页面:新建或编辑脚本的名称、备注与内容(带语法高亮)。
class ScriptEditScreen extends StatefulWidget {
  /// 创建脚本编辑页;[script] 为空且未提供初始值时表示新建。
  ///
  /// [initialName]/[initialContent]/[initialNote] 用于导入场景的预填,
  /// 保存时按新建脚本处理。
  const ScriptEditScreen({
    this.script,
    this.initialName,
    this.initialContent,
    this.initialNote,
    super.key,
  });

  /// 待编辑的脚本,为空时表示新建。
  final AppScript? script;

  /// 导入预填的脚本名。
  final String? initialName;

  /// 导入预填的脚本内容。
  final String? initialContent;

  /// 导入预填的备注。
  final String? initialNote;

  @override
  State<ScriptEditScreen> createState() => _ScriptEditScreenState();
}

class _ScriptEditScreenState extends State<ScriptEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late final CodeController _contentController;

  AppScript? get script => widget.script;

  bool get _isEditing => script != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: script?.name ?? widget.initialName ?? '',
    );
    _noteController = TextEditingController(
      text: script?.note ?? widget.initialNote ?? '',
    );
    _contentController = CodeController(
      text: script?.content ?? widget.initialContent ?? '',
      language: bash,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑脚本' : '新建脚本'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '脚本名称',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '脚本用途说明',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: CodeField(
                  controller: _contentController,
                  minLines: 10,
                  maxLines: 24,
                  expands: false,
                  wrap: true,
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.4,
                  ),
                  // 行号紧贴容器、内容贴近行号,减少冗余间距。
                  gutterStyle: const GutterStyle(
                    width: 36,
                    margin: 4,
                    showErrors: false,
                    showFoldingHandles: false,
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 校验并保存脚本。
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final controller = context.read<ScriptController>();
    final name = _nameController.text.trim();
    final note = _noteController.text.trim();
    final content = _contentController.text.trim();
    try {
      final current = script;
      if (current == null) {
        await controller.addScript(name, content, note);
      } else if (current.name == name) {
        await controller.updateScript(
          current.copyWith(content: content, note: note),
        );
      } else {
        await controller.renameScript(current, name);
        await controller.updateScript(
          current.copyWith(name: name, content: content, note: note),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('保存脚本失败', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败:$error')));
      }
    }
  }
}
