// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/logging/app_logger.dart';
import '../application/script_controller.dart';
import 'script_edit_screen.dart';

/// 从文件系统导入脚本。
///
/// 规则:
/// - 严格符合格式的 JSON 文件(name + content 字符串字段)直接导入当前文件夹;
/// - 非严格 JSON(字段缺失或无法解析)与 txt/log 等文本文件,
///   自动拉起脚本编辑页预填,用户点击保存后才算导入成功。
Future<void> importScript(BuildContext context) async {
  final controller = context.read<ScriptController>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  String? path;
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      dialogTitle: '选择脚本文件',
    );
    path = result?.files.single.path;
  } on Object catch (error, stackTrace) {
    AppLogger.e('选择脚本文件失败', error, stackTrace);
  }
  if (path == null) {
    return;
  }

  String content;
  try {
    content = await File(path).readAsString();
  } on Object catch (error, stackTrace) {
    AppLogger.e('读取脚本文件失败', error, stackTrace);
    messenger.showSnackBar(SnackBar(content: Text('读取文件失败:$error')));
    return;
  }

  final baseName = path
      .split(Platform.pathSeparator)
      .last
      .replaceAll(RegExp(r'\.json$'), '');

  final strict = _parseStrictJson(content);
  if (strict != null) {
    try {
      await controller.addScript(strict.name, strict.content, strict.note);
      messenger.showSnackBar(SnackBar(content: Text('脚本"${strict.name}"导入成功')));
      return;
    } on Object catch (error) {
      AppLogger.d('严格 JSON 导入冲突,转入编辑页:$error');
    }
  }

  // 非严格 JSON 或同名冲突:拉起编辑页预填,保存后才算导入。
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (context) => ScriptEditScreen(
        initialName: strict?.name ?? baseName,
        initialNote: strict?.note ?? '',
        initialContent: strict?.content ?? content,
      ),
    ),
  );
}

/// 尝试解析严格格式的脚本 JSON(含 name 与 content 字符串字段)。
///
/// 解析失败或字段不完整时返回 null。
ScriptImportData? _parseStrictJson(String content) {
  Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final name = decoded['name'];
  final scriptContent = decoded['content'];
  if (name is! String || name.trim().isEmpty || scriptContent is! String) {
    return null;
  }
  final note = decoded['note'];
  return ScriptImportData(
    name: name.trim(),
    content: scriptContent,
    note: note is String ? note : '',
  );
}

/// 严格 JSON 解析出的脚本数据。
class ScriptImportData {
  /// 创建导入数据。
  const ScriptImportData({
    required this.name,
    required this.content,
    required this.note,
  });

  /// 脚本名。
  final String name;

  /// 脚本内容。
  final String content;

  /// 备注。
  final String note;
}
