// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/paths/app_paths.dart';
import '../domain/app_script.dart';
import '../domain/script_folder.dart';

/// 脚本导出:脚本分享源 JSON 文件,文件夹压缩为 zip 后分享。
abstract final class ScriptExporter {
  const ScriptExporter._();

  /// 导出单个脚本为 JSON 文件并触发系统分享。
  static Future<void> exportScript(AppScript script) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}${script.fileName}',
    );
    await file.writeAsString(script.toJson(), flush: true);
    await _shareFile(file, '导出脚本 ${script.name}');
  }

  /// 导出文件夹为 zip 压缩包并触发系统分享。
  static Future<void> exportFolder(ScriptFolder folder) async {
    final root = await AppPaths.scriptsDirectory();
    final sourceDir = Directory(
      '${root.path}${Platform.pathSeparator}${folder.path.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!sourceDir.existsSync()) {
      throw StateError('脚本文件夹不存在:${folder.name}');
    }
    final archive = Archive();
    for (final entity in sourceDir.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final relative = entity.path
          .substring(sourceDir.path.length + 1)
          .replaceAll('\\', '/');
      final bytes = entity.readAsBytesSync();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes.isEmpty) {
      throw StateError('文件夹打包失败:${folder.name}');
    }
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}${folder.name}.zip',
    );
    await file.writeAsBytes(zipBytes, flush: true);
    await _shareFile(file, '导出文件夹 ${folder.name}');
  }

  /// 通过系统分享弹窗分享文件。
  static Future<void> _shareFile(File file, String subject) async {
    AppLogger.d('导出文件:${file.path}(${file.lengthSync()} bytes)');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: _mimeType(file.path))],
        text: subject,
      ),
    );
  }

  /// 依据扩展名推断 MIME 类型。
  static String _mimeType(String path) {
    final name = path.toLowerCase();
    if (name.endsWith('.json')) {
      return 'application/json';
    }
    if (name.endsWith('.zip')) {
      return 'application/zip';
    }
    return 'application/octet-stream';
  }
}
