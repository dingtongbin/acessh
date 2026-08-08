// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// 脚本文件夹领域模型。
///
/// [path] 为文件夹相对 scripts 根的路径(空串表示根目录),
/// [name] 为文件夹名称。
class ScriptFolder {
  /// 创建脚本文件夹。
  const ScriptFolder({required this.name, required this.path});

  /// 文件夹名称。
  final String name;

  /// 相对 scripts 根的路径(空串表示根目录)。
  final String path;

  /// 复制并替换部分字段。
  ScriptFolder copyWith({String? name, String? path}) {
    return ScriptFolder(name: name ?? this.name, path: path ?? this.path);
  }
}
