// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

/// 系统目录管理:应用数据统一存放在外部公共存储(卸载后保留),
/// 未获得"所有文件访问"权限时回退到应用内部目录。
class AppPaths {
  const AppPaths._();

  /// Android 公共外部存储下的数据根目录。
  static const String _publicRoot = '/storage/emulated/0/acessh';

  /// 应用数据根目录。
  ///
  /// Android 上优先使用公共目录 `/storage/emulated/0/acessh`:
  /// 卸载重装后数据仍然保留;未授权时回退应用内部目录(卸载即清除)。
  static Future<Directory> supportDirectory() async {
    if (Platform.isAndroid) {
      final publicDir = Directory(_publicRoot);
      try {
        if (!publicDir.existsSync()) {
          publicDir.createSync(recursive: true);
        }
        // 可写性探测:无权限时创建/写入会抛异常。
        final probe = File('${publicDir.path}${Platform.pathSeparator}.probe');
        probe.writeAsStringSync('ok');
        probe.deleteSync();
        return publicDir;
      } on Object {
        // 未授予"所有文件访问",回退应用内部目录。
      }
    }
    return getApplicationSupportDirectory();
  }

  /// 是否已使用公共外部存储目录(Android)。
  static Future<bool> isPublicStorageAvailable() async {
    if (!Platform.isAndroid) {
      return true;
    }
    final dir = await supportDirectory();
    return dir.path == _publicRoot;
  }

  /// 数据库文件完整路径。
  static Future<String> databasePath() async {
    final dir = await supportDirectory();
    return '${dir.path}${Platform.pathSeparator}${AppConstants.databaseFileName}';
  }

  /// 私钥目录(不存在时自动创建)。
  static Future<Directory> keysDirectory() async {
    final dir = await supportDirectory();
    final keysDir = Directory(
      '${dir.path}${Platform.pathSeparator}${AppConstants.keysDirectoryName}',
    );
    if (!keysDir.existsSync()) {
      await keysDir.create(recursive: true);
    }
    return keysDir;
  }

  /// 脚本根目录(不存在时自动创建),脚本以 JSON 文件按文件夹层级存放。
  static Future<Directory> scriptsDirectory() async {
    final dir = await supportDirectory();
    final scriptsDir = Directory('${dir.path}${Platform.pathSeparator}scripts');
    if (!scriptsDir.existsSync()) {
      await scriptsDir.create(recursive: true);
    }
    return scriptsDir;
  }

  /// 终端背景图片目录(不存在时自动创建)。
  static Future<Directory> backgroundsDirectory() async {
    final dir = await supportDirectory();
    final backgroundsDir = Directory(
      '${dir.path}${Platform.pathSeparator}backgrounds',
    );
    if (!backgroundsDir.existsSync()) {
      await backgroundsDir.create(recursive: true);
    }
    return backgroundsDir;
  }
}
