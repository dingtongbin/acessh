// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../paths/app_paths.dart';

/// 应用主密钥:32 字节随机密钥,用于加密所有密码类数据。
///
/// 密钥文件存放于会话目录下的 keys/ 保留目录(`sessions/keys/master.key`),
/// 首次需要时生成,之后复用。密钥与数据同机存储,防护目标是"文件被分享、
/// 备份或导出后直接读取",不防已取得设备 root/物理访问的攻击者。
class MasterKeyService {
  MasterKeyService._();

  /// 全局唯一实例。
  static final MasterKeyService instance = MasterKeyService._();

  String? _keyFilePathOverride;
  Future<SecretKey>? _keyFuture;

  /// 主密钥文件路径(测试可注入)。
  @visibleForTesting
  void overrideKeyFilePath(String path) {
    _keyFilePathOverride = path;
    _keyFuture = null;
  }

  /// 主密钥(懒加载:首次访问时读取或生成)。
  Future<SecretKey> get key => _keyFuture ??= _loadOrCreate();

  /// 读取主密钥文件;不存在时生成 32 字节随机密钥并写入。
  Future<SecretKey> _loadOrCreate() async {
    final file = File(await _keyFilePath());
    if (await file.exists()) {
      return SecretKey(_parseHex(await file.readAsString()));
    }
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = SecretKey(bytes);
    await file.writeAsString(_toHex(bytes), flush: true);
    return key;
  }

  /// 主密钥文件完整路径。
  Future<String> _keyFilePath() async {
    final override = _keyFilePathOverride;
    if (override != null) {
      return override;
    }
    final keysDir = await AppPaths.keysDirectory();
    return '${keysDir.path}${Platform.pathSeparator}'
        '${AppConstants.masterKeyFileName}';
  }

  /// 字节转小写十六进制。
  static String _toHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 十六进制文本解析为字节;非法输入抛出异常。
  static List<int> _parseHex(String text) {
    final trimmed = text.trim();
    if (trimmed.length != 64 ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(trimmed)) {
      throw StateError('主密钥文件损坏:${trimmed.length != 64 ? '长度错误' : '含非法字符'}');
    }
    return [
      for (var i = 0; i < 64; i += 2)
        int.parse(trimmed.substring(i, i + 2), radix: 16),
    ];
  }
}
