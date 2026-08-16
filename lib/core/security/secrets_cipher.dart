// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'master_key_service.dart';

/// 密码类字段的 AES-256-GCM 加解密。
///
/// 存储格式:`enc:v1:<base64(nonce‖cipherText‖mac)>`,每条数据使用随机
/// 12 字节 nonce,密文带 16 字节认证 tag(防篡改,解密失败即抛异常)。
/// 解密时无 `enc:v1:` 前缀的值按明文原样返回,兼容旧明文数据与
/// AceShell 明文会话文件;写入一律加密。
class SecretsCipher {
  /// 创建加密器;[key] 为 256 位密钥(懒加载,首次使用才就绪)。
  SecretsCipher(Future<SecretKey> key) : _keyFuture = key;

  /// 使用应用主密钥创建加密器。
  SecretsCipher.fromMasterKey([MasterKeyService? service])
    : _keyFuture = (service ?? MasterKeyService.instance).key;

  /// 密文存储前缀。
  static const String prefix = 'enc:v1:';

  final Future<SecretKey> _keyFuture;

  /// 加密明文为带前缀的存储格式。
  Future<String> encrypt(String plaintext) async {
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: await _keyFuture,
      nonce: nonce,
    );
    return '$prefix${base64Encode(secretBox.concatenation())}';
  }

  /// 解密存储值;无前缀时按明文原样返回(兼容旧数据)。
  ///
  /// 前缀存在但解密失败(密钥不匹配或被篡改)时抛出异常。
  Future<String> decrypt(String value) async {
    if (!value.startsWith(prefix)) {
      return value;
    }
    final algorithm = AesGcm.with256bits();
    final bytes = base64Decode(value.substring(prefix.length));
    final decrypted = await algorithm.decrypt(
      SecretBox.fromConcatenation(
        bytes,
        nonceLength: algorithm.nonceLength,
        // AES-GCM 认证 tag 固定 16 字节。
        macLength: 16,
      ),
      secretKey: await _keyFuture,
    );
    return utf8.decode(decrypted);
  }

  /// 是否加密存储值(带前缀)。
  static bool isEncrypted(String value) => value.startsWith(prefix);
}
