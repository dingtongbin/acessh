// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

/// 脚本领域模型:以 JSON 文件形式存储在系统固定目录的 scripts 目录下。
///
/// 文件名为 "<脚本名>.json",界面展示时不带后缀;
/// [folderPath] 为所属文件夹相对 scripts 根的路径,空串表示根目录。
class AppScript {
  /// 脚本名称(不含扩展名,唯一)。
  final String name;

  /// 脚本内容(多行命令)。
  final String content;

  /// 备注(用途说明)。
  final String note;

  /// 所属文件夹相对路径(空串表示根目录)。
  final String folderPath;

  /// 创建时间戳(毫秒)。
  final int createdAt;

  /// 最后修改时间戳(毫秒)。
  final int updatedAt;

  /// 累计执行次数。
  final int executeCount;

  /// 创建脚本。
  const AppScript({
    required this.name,
    required this.content,
    required this.note,
    required this.folderPath,
    required this.createdAt,
    required this.updatedAt,
    required this.executeCount,
  });

  /// 脚本文件完整文件名。
  String get fileName => '$name.json';

  /// 脚本相对 scripts 根的完整路径。
  String get fullPath =>
      folderPath.isEmpty ? fileName : '$folderPath/$fileName';

  /// 复制并替换部分字段。
  AppScript copyWith({
    String? name,
    String? content,
    String? note,
    String? folderPath,
    int? createdAt,
    int? updatedAt,
    int? executeCount,
  }) {
    return AppScript(
      name: name ?? this.name,
      content: content ?? this.content,
      note: note ?? this.note,
      folderPath: folderPath ?? this.folderPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      executeCount: executeCount ?? this.executeCount,
    );
  }

  /// 从 JSON 文本解析。
  factory AppScript.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return AppScript(
      name: map['name'] as String,
      content: map['content'] as String? ?? '',
      note: map['note'] as String? ?? '',
      folderPath: map['folder_path'] as String? ?? '',
      createdAt: map['created_at'] as int? ?? 0,
      updatedAt: map['updated_at'] as int? ?? 0,
      executeCount: map['execute_count'] as int? ?? 0,
    );
  }

  /// 序列化为 JSON 文本。
  String toJson() {
    return jsonEncode({
      'name': name,
      'content': content,
      'note': note,
      'folder_path': folderPath,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'execute_count': executeCount,
    });
  }
}
