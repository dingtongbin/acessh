// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import '../../../core/logging/app_logger.dart';
import '../../../core/paths/app_paths.dart';
import '../domain/app_script.dart';
import '../domain/script_folder.dart';

/// 脚本文件系统数据访问:脚本以 JSON 文件存储于系统固定目录的 scripts 目录,
/// 文件夹对应目录层级,支持嵌套。
class ScriptFileRepository {
  /// 创建脚本文件仓库;[root] 用于测试时指定临时根目录。
  const ScriptFileRepository({Directory? root}) : _rootOverride = root;

  /// 测试注入的根目录,为空时使用系统固定目录。
  final Directory? _rootOverride;

  /// 脚本根目录。
  Future<Directory> _root() async =>
      _rootOverride ?? await AppPaths.scriptsDirectory();

  /// 校验文件夹相对路径合法性,并返回其绝对目录(不存在时报错)。
  ///
  /// 路径必须为相对路径,禁止空段、`.`、`..` 与首尾分隔符,防止越权访问。
  Future<Directory> _folderDir(
    String folderPath, {
    bool mustExist = false,
  }) async {
    final normalized = _normalizeFolderPath(folderPath);
    final root = await _root();
    final dir = Directory(
      normalized.isEmpty
          ? root.path
          : '${root.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}',
    );
    if (mustExist && !dir.existsSync()) {
      throw StateError('脚本文件夹不存在:$normalized');
    }
    return dir;
  }

  /// 规范化并校验文件夹相对路径。
  String _normalizeFolderPath(String folderPath) {
    final trimmed = folderPath.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final segments = trimmed.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.any((s) => s == '.' || s == '..')) {
      throw ArgumentError('文件夹路径不合法:$folderPath');
    }
    return segments.join('/');
  }

  /// 校验脚本名/文件夹名合法(禁止路径分隔符与系统保留字符)。
  void _validateEntryName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('名称不能为空');
    }
    if (trimmed.contains('/') ||
        trimmed.contains('\\') ||
        trimmed.contains('..')) {
      throw ArgumentError('名称不能包含路径分隔符');
    }
    if (trimmed == '.' || trimmed == '..') {
      throw ArgumentError('名称不合法');
    }
  }

  /// 列出 [folderPath] 下的子文件夹,按名称排序。
  Future<List<ScriptFolder>> listFolders(String folderPath) async {
    final dir = await _folderDir(folderPath, mustExist: true);
    final folders = <ScriptFolder>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) {
        continue;
      }
      final name = entity.path.split(Platform.pathSeparator).last;
      final childPath = folderPath.trim().isEmpty
          ? name
          : '${folderPath.trim()}/$name';
      folders.add(ScriptFolder(name: name, path: childPath));
    }
    folders.sort((a, b) => a.name.compareTo(b.name));
    return folders;
  }

  /// 列出 [folderPath] 下的脚本,按名称排序。
  Future<List<AppScript>> listScripts(String folderPath) async {
    final dir = await _folderDir(folderPath, mustExist: true);
    final scripts = <AppScript>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      try {
        final script = AppScript.fromJson(await entity.readAsString());
        scripts.add(script);
      } on Object catch (error, stackTrace) {
        AppLogger.e('读取脚本失败:${entity.path}', error, stackTrace);
      }
    }
    scripts.sort((a, b) => a.name.compareTo(b.name));
    return scripts;
  }

  /// 在 [folderPath] 下新建文件夹 [name],重名时抛出异常。
  Future<void> createFolder(String folderPath, String name) async {
    _validateEntryName(name);
    final parent = await _folderDir(folderPath, mustExist: true);
    final target = Directory('${parent.path}${Platform.pathSeparator}$name');
    if (target.existsSync()) {
      throw StateError('文件夹已存在:$name');
    }
    await target.create(recursive: false);
  }

  /// 重命名 [folderPath] 下的文件夹 [oldName] 为 [newName]。
  Future<void> renameFolder(
    String folderPath,
    String oldName,
    String newName,
  ) async {
    _validateEntryName(newName);
    final parent = await _folderDir(folderPath, mustExist: true);
    final source = Directory('${parent.path}${Platform.pathSeparator}$oldName');
    if (!source.existsSync()) {
      throw StateError('文件夹不存在:$oldName');
    }
    final target = Directory('${parent.path}${Platform.pathSeparator}$newName');
    if (target.existsSync()) {
      throw StateError('文件夹已存在:$newName');
    }
    await source.rename(target.path);
  }

  /// 递归删除 [folderPath] 下的文件夹 [name](含全部子内容)。
  Future<void> deleteFolder(String folderPath, String name) async {
    final parent = await _folderDir(folderPath, mustExist: true);
    final target = Directory('${parent.path}${Platform.pathSeparator}$name');
    if (!target.existsSync()) {
      throw StateError('文件夹不存在:$name');
    }
    await target.delete(recursive: true);
  }

  /// 保存脚本(新建或更新);同名脚本已存在时抛出异常。
  Future<void> saveScript(AppScript script) async {
    _validateEntryName(script.name);
    final dir = await _folderDir(script.folderPath, mustExist: true);
    final file = File('${dir.path}${Platform.pathSeparator}${script.fileName}');
    if (file.existsSync()) {
      throw StateError('脚本已存在:${script.name}');
    }
    await file.writeAsString(script.toJson(), flush: true);
  }

  /// 更新已存在的脚本(按 [script.fullPath] 定位)。
  Future<void> updateScript(AppScript script) async {
    final dir = await _folderDir(script.folderPath, mustExist: true);
    final file = File('${dir.path}${Platform.pathSeparator}${script.fileName}');
    if (!file.existsSync()) {
      throw StateError('脚本不存在:${script.name}');
    }
    await file.writeAsString(script.toJson(), flush: true);
  }

  /// 重命名脚本(更新文件名与内部 name 字段)。
  Future<void> renameScript(
    String folderPath,
    String oldName,
    String newName,
  ) async {
    _validateEntryName(newName);
    final dir = await _folderDir(folderPath, mustExist: true);
    final source = File('${dir.path}${Platform.pathSeparator}$oldName.json');
    if (!source.existsSync()) {
      throw StateError('脚本不存在:$oldName');
    }
    if (oldName == newName) {
      return;
    }
    final target = File('${dir.path}${Platform.pathSeparator}$newName.json');
    if (target.existsSync()) {
      throw StateError('脚本已存在:$newName');
    }
    final script = AppScript.fromJson(await source.readAsString());
    final renamed = script.copyWith(name: newName);
    await target.writeAsString(renamed.toJson(), flush: true);
    await source.delete();
  }

  /// 删除脚本。
  Future<void> deleteScript(String folderPath, String name) async {
    final dir = await _folderDir(folderPath, mustExist: true);
    final file = File('${dir.path}${Platform.pathSeparator}$name.json');
    if (!file.existsSync()) {
      throw StateError('脚本不存在:$name');
    }
    await file.delete();
  }

  /// 读取单个脚本,不存在返回 null。
  Future<AppScript?> readScript(String folderPath, String name) async {
    final dir = await _folderDir(folderPath, mustExist: true);
    final file = File('${dir.path}${Platform.pathSeparator}$name.json');
    if (!file.existsSync()) {
      return null;
    }
    return AppScript.fromJson(await file.readAsString());
  }

  /// 记录脚本执行一次(执行次数 +1 并回写文件)。
  Future<void> recordExecuted(AppScript script) async {
    final current = await readScript(script.folderPath, script.name);
    if (current == null) {
      return;
    }
    await updateScript(
      current.copyWith(
        executeCount: current.executeCount + 1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
