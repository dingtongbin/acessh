// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartssh2/dartssh2.dart';

/// SSH 私钥服务:生成 Ed25519 密钥对、编码为 OpenSSH PEM、校验导入的密钥。
///
/// dartssh2 不提供密钥生成,因此用 cryptography 生成原始字节,
/// 再按 OpenSSH v1 私有密钥格式编码为 PEM 文本。
class SshKeyService {
  const SshKeyService._();

  /// 生成一对 Ed25519 密钥,返回 OpenSSH 格式的私钥 PEM 文本。
  ///
  /// OpenSSH 私钥字段为 seed(32) 拼接公钥(32),共 64 字节。
  static Future<String> generateEd25519({String comment = 'acessh'}) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final seed = await keyPair.extractPrivateKeyBytes();
    final publicKeyBytes = Uint8List.fromList(publicKey.bytes);
    return _encodeOpenSshPem(
      publicKey: publicKeyBytes,
      privateKey: Uint8List.fromList([...seed, ...publicKeyBytes]),
      comment: comment,
    );
  }

  /// 校验 PEM 文本是否为可解析的 OpenSSH 私钥。
  static bool isValidPem(String pem) {
    final trimmed = pem.trim();
    if (!trimmed.contains('-----BEGIN')) {
      return false;
    }
    try {
      return SSHKeyPair.fromPem(trimmed).isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// 解析 PEM 文本为可用的密钥对列表(加密密钥会抛异常)。
  static List<SSHKeyPair> parsePem(String pem) {
    return SSHKeyPair.fromPem(pem.trim());
  }

  /// 将原始 Ed25519 密钥编码为 OpenSSH v1 私有密钥 PEM。
  static String _encodeOpenSshPem({
    required Uint8List publicKey,
    required Uint8List privateKey,
    required String comment,
  }) {
    final checkInt = Random.secure().nextInt(0xFFFFFFFF);

    final privateBlob = BytesBuilder();
    privateBlob.add(_uint32(checkInt));
    privateBlob.add(_uint32(checkInt));
    privateBlob.add(_string(utf8.encode('ssh-ed25519')));
    privateBlob.add(_string(publicKey));
    privateBlob.add(_string(privateKey));
    privateBlob.add(_string(utf8.encode(comment)));
    for (var i = 0; privateBlob.length % 8 != 0; i++) {
      privateBlob.add([i + 1]);
    }

    final container = BytesBuilder();
    container.add(utf8.encode('openssh-key-v1'));
    container.add([0]); // magic 结束符
    container.add(_string(utf8.encode('none'))); // cipher name
    container.add(_string(utf8.encode('none'))); // kdf name
    container.add(_uint32(0)); // kdf options 长度
    container.add(_uint32(1)); // 密钥数量
    final publicBlob = BytesBuilder()
      ..add(_string(utf8.encode('ssh-ed25519')))
      ..add(_string(publicKey));
    container.add(_string(publicBlob.toBytes()));
    container.add(_string(privateBlob.toBytes()));

    final b64 = base64.encode(container.toBytes());
    final lines = <String>[
      '-----BEGIN OPENSSH PRIVATE KEY-----',
      for (var i = 0; i < b64.length; i += 70)
        b64.substring(i, min(i + 70, b64.length)),
      '-----END OPENSSH PRIVATE KEY-----',
    ];
    return lines.join('\n');
  }

  /// 编码 uint32 大端字节。
  static Uint8List _uint32(int value) {
    return Uint8List(4)
      ..[0] = (value >> 24) & 0xFF
      ..[1] = (value >> 16) & 0xFF
      ..[2] = (value >> 8) & 0xFF
      ..[3] = value & 0xFF;
  }

  /// 编码 SSH 长度前缀字符串。
  static Uint8List _string(List<int> bytes) {
    return Uint8List.fromList([..._uint32(bytes.length), ...bytes]);
  }
}
