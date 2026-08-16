// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

import '../../connection/application/ssh_key_service.dart';
import '../../connection/domain/stored_key.dart';

/// 导出包的会话条目(相对会话根目录的 ZIP 路径与原始字节)。
typedef SessionPackageEntry = ({String entryPath, Uint8List bytes});

/// 导入包内容:会话文件(文件夹/会话名/原始字节)与密钥列表。
typedef ImportPackage = ({
  List<({String folder, String name, Uint8List bytes})> sessions,
  List<StoredKey> keys,
});

/// 导出密码合规策略:8~64 位,大写/小写/数字/符号至少三类。
abstract final class ExportPasswordPolicy {
  const ExportPasswordPolicy._();

  /// 最小长度。
  static const int minLength = 8;

  /// 最大长度。
  static const int maxLength = 64;

  /// 需要覆盖的字符类别数。
  static const int requiredCategories = 3;

  /// 校验密码;返回 null 表示合规,否则为错误提示文案。
  static String? validate(String password) {
    if (password.length < minLength || password.length > maxLength) {
      return '密码长度需 $minLength~$maxLength 位';
    }
    final count = categoryCount(password);
    if (count < requiredCategories) {
      return '密码需包含大写/小写/数字/符号中至少 $requiredCategories 类'
          '(当前 $count 类,缺 ${missingCategories(password).join("、")})';
    }
    return null;
  }

  /// 已覆盖的字符类别数(逐字符位掩码统计)。
  static int categoryCount(String password) {
    return _categories(password).length;
  }

  /// 尚未覆盖的类别名列表(如 ["大写字母", "数字"])。
  static List<String> missingCategories(String password) {
    const all = ['大写字母', '小写字母', '数字', '符号'];
    return [
      for (final (index, name) in all.indexed)
        if (!_categories(password).contains(index)) name,
    ];
  }

  /// 已覆盖类别的索引集合(0 大写/1 小写/2 数字/3 符号)。
  static Set<int> _categories(String password) {
    final categories = <int>{};
    for (final rune in password.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[A-Z]').hasMatch(char)) {
        categories.add(0);
      } else if (RegExp(r'[a-z]').hasMatch(char)) {
        categories.add(1);
      } else if (RegExp(r'[0-9]').hasMatch(char)) {
        categories.add(2);
      } else {
        categories.add(3);
      }
    }
    return categories;
  }
}

/// 设备导出/导入加密服务(as9 二进制包,对齐 AceShell 设计)。
///
/// 导出流程:
/// 1. 收集勾选会话的 .toml **原样字节**(含本地 enc:v1: 密码密文)与
///    勾选密钥的**明文 JSON**(私钥/口令/公钥/时间戳),打包为 ZIP;
/// 2. 用户密码经 PBKDF2-SHA256(16 字节随机盐,10 万次迭代)派生
///    AES-256 密钥;
/// 3. AES-256-GCM(12 字节随机 nonce)加密整个 ZIP,密文带 16 字节认证 Tag。
///
/// 最终二进制布局:`[0..8) 魔数 "ACEAS9V1" | [8..24) Salt | [24..36) Nonce |
/// [36..) 密文 + Tag`。同一密码多次导出密文不同(盐与 nonce 随机)。
///
/// 密钥 JSON 在包内为明文:as9 包本身已加密,对外仍是密文;
/// 若包内再加密,另一台机器没有本机主密钥就无法解密使用。
/// 会话 TOML 原样携带:跨机器导入后 enc:v1: 密文解不开,按无密码处理。
class DeviceTransferService {
  const DeviceTransferService._();

  /// 包魔数(ASCII)。
  static const String magic = 'ACEAS9V1';

  /// PBKDF2 迭代次数。
  static const int pbkdf2Iterations = 100000;

  /// 盐长度(字节)。
  static const int saltLength = 16;

  /// AES-GCM nonce 长度(字节)。
  static const int nonceLength = 12;

  /// 导出:打包 ZIP 并加密为 as9 二进制。
  ///
  /// [sessionFiles] 为勾选会话(相对会话根目录的条目路径 + 原始字节);
  /// [keys] 为勾选密钥(包内以明文 JSON 写入 `key/<名称>.json`)。
  static Future<Uint8List> exportPackage({
    required List<SessionPackageEntry> sessionFiles,
    required List<StoredKey> keys,
    required String password,
  }) async {
    final archive = Archive();
    for (final entry in sessionFiles) {
      archive.addFile(
        ArchiveFile(entry.entryPath, entry.bytes.length, entry.bytes),
      );
    }
    for (final key in keys) {
      final json = utf8.encode(jsonEncode(_keyToJson(key)));
      archive.addFile(ArchiveFile('key/${key.name}.json', json.length, json));
    }
    final zipBytes = ZipEncoder().encode(archive);

    final algorithm = AesGcm.with256bits();
    final salt = _randomBytes(saltLength);
    final derivedKey = await _deriveKey(password, salt);
    final nonce = algorithm.newNonce();
    final box = await algorithm.encrypt(
      zipBytes,
      secretKey: derivedKey,
      nonce: nonce,
    );

    final out = BytesBuilder();
    out.add(utf8.encode(magic));
    out.add(salt);
    out.add(nonce);
    out.add(box.concatenation());
    return out.toBytes();
  }

  /// 导入:校验并解密 as9 包,返回包内会话与密钥。
  ///
  /// 魔数不匹配/长度不足抛 [FormatException]("包已损坏");
  /// GCM 认证失败(密码错误或被篡改)抛 [StateError]("密码错误或加密包已损坏")。
  static Future<ImportPackage> importPackage({
    required Uint8List bytes,
    required String password,
  }) async {
    if (bytes.length < magic.length + saltLength + nonceLength) {
      throw const FormatException('包已损坏');
    }
    if (utf8.decode(bytes.sublist(0, magic.length)) != magic) {
      throw const FormatException('包已损坏');
    }
    final salt = bytes.sublist(magic.length, magic.length + saltLength);
    // Nonce 位于 [24..36),随密文一并由 SecretBox 还原,此处只需定位密文。
    final cipher = bytes.sublist(magic.length + saltLength + nonceLength);

    final derivedKey = await _deriveKey(password, salt);
    final algorithm = AesGcm.with256bits();
    final Uint8List zipBytes;
    try {
      final decrypted = await algorithm.decrypt(
        SecretBox.fromConcatenation(
          cipher,
          nonceLength: nonceLength,
          macLength: 16,
        ),
        secretKey: derivedKey,
      );
      zipBytes = Uint8List.fromList(decrypted);
    } on Object {
      throw StateError('密码错误或加密包已损坏');
    }

    final archive = ZipDecoder().decodeBytes(zipBytes);
    final sessions = <({String folder, String name, Uint8List bytes})>[];
    final keys = <StoredKey>[];
    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final entryName = file.name;
      final content = Uint8List.fromList(file.content as List<int>);
      if (entryName.startsWith('key/')) {
        final json = jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
        keys.add(
          StoredKey(
            name: json['name'] as String? ?? '',
            privateKey: json['private_key'] as String? ?? '',
            passphrase: json['passphrase'] as String? ?? '',
            createdAt: json['created_at'] as int? ?? 0,
          ),
        );
      } else if (entryName.endsWith('.toml')) {
        final parsed = _parseSessionEntry(entryName, content);
        if (parsed != null) {
          sessions.add(parsed);
        }
      }
    }
    return (sessions: sessions, keys: keys);
  }

  /// 解析会话条目 `[文件夹/]会话名.toml`,路径越界(..)时返回 null。
  static ({String folder, String name, Uint8List bytes})? _parseSessionEntry(
    String entryName,
    Uint8List bytes,
  ) {
    final parts = entryName.split('/');
    if (parts.any((part) => part.isEmpty || part == '..')) {
      return null;
    }
    final fileName = parts.last;
    final folder = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join('/')
        : '';
    return (
      folder: folder,
      name: fileName.substring(0, fileName.length - '.toml'.length),
      bytes: bytes,
    );
  }

  /// 密钥 → 明文 JSON(包内密钥条目;as9 包本身加密,此处不套本地主密钥)。
  static Map<String, dynamic> _keyToJson(StoredKey key) {
    String? publicKey;
    try {
      publicKey = SshKeyService.derivePublicKey(key.privateKey);
    } on Object {
      // 私钥损坏时省略公钥,不影响其余字段。
    }
    return {
      'name': key.name,
      'private_key': key.privateKey,
      'passphrase': key.passphrase,
      'public_key': ?publicKey,
      'created_at': key.createdAt,
    };
  }

  /// 由密码与盐派生 256 位密钥。
  static Future<SecretKey> _deriveKey(String password, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// 生成加密安全随机字节。
  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
