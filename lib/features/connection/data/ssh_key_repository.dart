// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';
import 'dart:io';

import '../../../core/logging/app_logger.dart';
import '../../../core/paths/app_paths.dart';
import '../../../core/security/secrets_cipher.dart';
import '../domain/stored_key.dart';

/// 全局密钥库:密钥库目录(sessions/keys/)下一个密钥一个 JSON 文件。
///
/// JSON 中 `private_key` 与 `passphrase` 经 AES-GCM 加密落盘;
/// 密钥名自动生成(`Ed25519-<yyyyMMdd-HHmm>`,同秒冲突追加序号),
/// 密钥独立于设备存在,可被多个设备通过 key_path 引用。
class SshKeyRepository {
  /// 创建密钥仓库;不传目录时使用全局密钥库目录,测试可注入临时目录。
  SshKeyRepository({String? directory, SecretsCipher? cipher})
    : _directoryFuture = directory != null
          ? Future.value(Directory(directory))
          : AppPaths.keysDirectory(),
      _cipher = cipher ?? SecretsCipher.fromMasterKey();

  final Future<Directory> _directoryFuture;
  final SecretsCipher _cipher;

  /// 密钥 JSON 文件扩展名。
  static const String fileExtension = '.json';

  /// 全部密钥(按创建时间倒序),master.key 等非 JSON 文件自动排除。
  Future<List<StoredKey>> listKeys() async {
    final dir = await _directoryFuture;
    if (!await dir.exists()) {
      return [];
    }
    final keys = <StoredKey>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith(fileExtension)) {
        continue;
      }
      final key = await _readKeyFile(entity);
      if (key != null) {
        keys.add(key);
      }
    }
    keys.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return keys;
  }

  /// 按密钥名加载单个密钥,不存在返回 null。
  Future<StoredKey?> loadKey(String name) async {
    final file = await _fileFor(name);
    if (!await file.exists()) {
      return null;
    }
    return _readKeyFile(file);
  }

  /// 生成密钥 JSON 文件路径。
  Future<String> resolvePath(String name) async {
    return (await _fileFor(name)).path;
  }

  /// 创建密钥:加密落盘,返回带文件路径的密钥记录。
  ///
  /// [name] 为导入场景指定的密钥名(为空时自动生成 `Ed25519-<时间>`),
  /// 已存在同名时追加序号; [createdAt] 为导入场景保留的原始创建时间。
  Future<StoredKey> createKey({
    required String privateKey,
    String passphrase = '',
    String? name,
    int? createdAt,
  }) async {
    final dir = await _directoryFuture;
    final now = createdAt ?? DateTime.now().millisecondsSinceEpoch;
    var candidate = (name == null || name.isEmpty) ? _autoName() : name;
    var file = File(
      '${dir.path}${Platform.pathSeparator}$candidate$fileExtension',
    );
    var index = 2;
    while (await file.exists()) {
      candidate = '${name ?? _autoName()}-$index';
      file = File(
        '${dir.path}${Platform.pathSeparator}$candidate$fileExtension',
      );
      index++;
    }
    final key = StoredKey(
      name: candidate,
      privateKey: privateKey,
      passphrase: passphrase,
      createdAt: now,
      filePath: file.path,
    );
    await _writeKeyFile(key);
    return key;
  }

  /// 删除密钥;被引用该密钥的设备连接时将提示密钥未配置。
  Future<void> deleteKey(String name) async {
    final file = await _fileFor(name);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 密钥 JSON 文件。
  Future<File> _fileFor(String name) async {
    final dir = await _directoryFuture;
    return File('${dir.path}${Platform.pathSeparator}$name$fileExtension');
  }

  /// 自动密钥名:`Ed25519-<yyyyMMdd-HHmm>`。
  String _autoName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Ed25519-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}';
  }

  /// 加密敏感字段后写入密钥 JSON 文件。
  Future<void> _writeKeyFile(StoredKey key) async {
    final json = key.toJson();
    json['private_key'] = await _cipher.encrypt(key.privateKey);
    json['passphrase'] = key.passphrase.isEmpty
        ? ''
        : await _cipher.encrypt(key.passphrase);
    await File(key.filePath).writeAsString(jsonEncode(json), flush: true);
  }

  /// 读取并解密单个密钥文件;损坏文件返回 null 并记录日志。
  Future<StoredKey?> _readKeyFile(File file) async {
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final parsed = StoredKey.fromJson(json);
      return StoredKey(
        name: parsed.name,
        privateKey: await _decryptField(json['private_key'] as String? ?? ''),
        passphrase: await _decryptField(json['passphrase'] as String? ?? ''),
        createdAt: parsed.createdAt,
        filePath: file.path,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('解析密钥文件失败:${file.path}', error, stackTrace);
      return null;
    }
  }

  /// 解密存储字段;空串或明文(无前缀)原样返回,兼容旧数据。
  Future<String> _decryptField(String value) async {
    if (value.isEmpty || !SecretsCipher.isEncrypted(value)) {
      return value;
    }
    try {
      return await _cipher.decrypt(value);
    } on Object catch (error, stackTrace) {
      AppLogger.e('密钥字段解密失败', error, stackTrace);
      return '';
    }
  }
}
