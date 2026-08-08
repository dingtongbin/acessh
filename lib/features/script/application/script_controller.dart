// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/foundation.dart';

import '../data/script_file_repository.dart';
import '../domain/app_script.dart';
import '../domain/script_folder.dart';

/// 脚本列表状态:基于文件系统维护当前文件夹的脚本与文件夹列表,
/// 提供文件夹导航与增删改查。
class ScriptController extends ChangeNotifier {
  /// 创建脚本控制器;不传仓库时使用默认文件系统仓库。
  ScriptController([ScriptFileRepository? repository])
    : _repository = repository ?? ScriptFileRepository();

  /// 全局唯一实例。
  static final ScriptController instance = ScriptController();

  final ScriptFileRepository _repository;

  String _currentFolder = '';
  List<ScriptFolder> _folders = [];
  List<AppScript> _scripts = [];

  /// 当前浏览的文件夹相对路径(空串表示根目录"脚本目录")。
  String get currentFolder => _currentFolder;

  /// 当前文件夹展示名(根目录显示"脚本管理")。
  String get currentFolderName =>
      _currentFolder.isEmpty ? '脚本管理' : _currentFolder.split('/').last;

  /// 当前文件夹下的子文件夹。
  List<ScriptFolder> get folders => List.unmodifiable(_folders);

  /// 当前文件夹下的脚本。
  List<AppScript> get scripts => List.unmodifiable(_scripts);

  /// 当前文件夹的父文件夹路径(根目录时为空串)。
  String get parentFolder {
    if (_currentFolder.isEmpty) {
      return '';
    }
    final segments = _currentFolder.split('/')..removeLast();
    return segments.join('/');
  }

  /// 加载当前文件夹内容(子文件夹与脚本)。
  Future<void> load() async {
    _folders = await _repository.listFolders(_currentFolder);
    _scripts = await _repository.listScripts(_currentFolder);
    notifyListeners();
  }

  /// 进入子文件夹。
  Future<void> enterFolder(ScriptFolder folder) async {
    _currentFolder = folder.path;
    await load();
  }

  /// 返回上一级文件夹(根目录时无操作)。
  Future<void> leaveFolder() async {
    if (_currentFolder.isEmpty) {
      return;
    }
    _currentFolder = parentFolder;
    await load();
  }

  /// 新建子文件夹。
  Future<void> createFolder(String name) async {
    await _repository.createFolder(_currentFolder, name);
    await load();
  }

  /// 重命名当前文件夹下的文件夹。
  Future<void> renameFolder(ScriptFolder folder, String newName) async {
    await _repository.renameFolder(_currentFolder, folder.name, newName);
    if (_currentFolder == folder.path) {
      // 当前浏览的文件夹被重命名,需要同步路径。
      _currentFolder = _replaceLastSegment(_currentFolder, newName);
    }
    await load();
  }

  /// 删除当前文件夹下的文件夹(含全部子内容)。
  Future<void> deleteFolder(ScriptFolder folder) async {
    await _repository.deleteFolder(_currentFolder, folder.name);
    await load();
  }

  /// 新建脚本。
  Future<void> addScript(String name, String content, String note) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _repository.saveScript(
      AppScript(
        name: name,
        content: content,
        note: note,
        folderPath: _currentFolder,
        createdAt: now,
        updatedAt: now,
        executeCount: 0,
      ),
    );
    await load();
  }

  /// 更新脚本内容与备注。
  Future<void> updateScript(AppScript script) async {
    await _repository.updateScript(
      script.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch),
    );
    await load();
  }

  /// 重命名当前文件夹下的脚本。
  Future<void> renameScript(AppScript script, String newName) async {
    await _repository.renameScript(_currentFolder, script.name, newName);
    await load();
  }

  /// 删除当前文件夹下的脚本。
  Future<void> deleteScript(AppScript script) async {
    await _repository.deleteScript(_currentFolder, script.name);
    await load();
  }

  /// 记录脚本执行一次(执行次数 +1)。
  Future<void> recordExecuted(AppScript script) async {
    await _repository.recordExecuted(script);
    await load();
  }

  /// 将路径最后一段替换为新名称。
  static String _replaceLastSegment(String path, String newName) {
    final segments = path.split('/')..removeLast();
    segments.add(newName);
    return segments.join('/');
  }
}
