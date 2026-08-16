// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';
import 'dart:io';

import 'package:acessh/core/security/master_key_service.dart';
import 'package:acessh/core/security/secrets_cipher.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecretsCipher', () {
    final cipher = SecretsCipher(
      Future.value(SecretKey(List<int>.filled(32, 7))),
    );

    test('加密往返,密文带 enc:v1: 前缀', () async {
      final encrypted = await cipher.encrypt('secret-password');
      expect(encrypted, startsWith(SecretsCipher.prefix));
      expect(SecretsCipher.isEncrypted(encrypted), isTrue);
      expect(await cipher.decrypt(encrypted), 'secret-password');
    });

    test('同一明文两次加密密文不同(随机 nonce),解密一致', () async {
      final a = await cipher.encrypt('same');
      final b = await cipher.encrypt('same');
      expect(a, isNot(equals(b)));
      expect(await cipher.decrypt(a), 'same');
      expect(await cipher.decrypt(b), 'same');
    });

    test('篡改密文(认证 tag 损坏)后解密失败', () async {
      final encrypted = await cipher.encrypt('data');
      final bytes = base64Decode(
        encrypted.substring(SecretsCipher.prefix.length),
      );
      bytes[bytes.length - 1] ^= 0x01; // 翻转 mac 最后一位。
      final tampered = '${SecretsCipher.prefix}${base64Encode(bytes)}';
      await expectLater(cipher.decrypt(tampered), throwsA(anything));
    });

    test('无前缀值(旧明文数据)原样返回', () async {
      expect(await cipher.decrypt('plain-text'), 'plain-text');
      expect(await cipher.decrypt(''), '');
    });

    test('不同密钥无法解密', () async {
      final other = SecretsCipher(
        Future.value(SecretKey(List<int>.filled(32, 9))),
      );
      final encrypted = await cipher.encrypt('cross-key');
      await expectLater(other.decrypt(encrypted), throwsA(anything));
    });
  });

  group('MasterKeyService', () {
    test('首次生成 32 字节密钥文件,重启后复用同一密钥', () async {
      final dir = await Directory.systemTemp.createTemp('acessh_masterkey_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}master.key';

      final service = MasterKeyService.instance..overrideKeyFilePath(path);
      final key1 = await service.key;
      final bytes1 = await key1.extractBytes();
      expect(bytes1.length, 32);

      // 模拟重启:重新加载同一文件。
      service.overrideKeyFilePath(path);
      final key2 = await service.key;
      expect(await key2.extractBytes(), bytes1);

      // 密钥文件为 64 位十六进制。
      final content = await File(path).readAsString();
      expect(content.trim(), matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('损坏的密钥文件抛出异常', () async {
      final dir = await Directory.systemTemp.createTemp('acessh_masterkey_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}master.key';
      await File(path).writeAsString('not-hex');

      final service = MasterKeyService.instance..overrideKeyFilePath(path);
      await expectLater(service.key, throwsA(isA<StateError>()));
    });
  });
}
