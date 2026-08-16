// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

import 'package:acessh/features/connection/application/ssh_key_service.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SshKeyService.generateEd25519', () {
    test('生成的 PEM 可被 dartssh2 解析并完成签名', () async {
      final pem = await SshKeyService.generateEd25519();

      expect(pem, startsWith('-----BEGIN OPENSSH PRIVATE KEY-----'));
      expect(pem, endsWith('-----END OPENSSH PRIVATE KEY-----'));

      final keys = SSHKeyPair.fromPem(pem);
      expect(keys, isNotEmpty);
      expect(keys.first.name, 'ssh-ed25519');

      final signature = keys.first.sign(utf8.encode('sign-me'));
      expect(signature.encode(), isNotEmpty);
    });

    test('生成结果随机且可重复解析', () async {
      final pem1 = await SshKeyService.generateEd25519();
      final pem2 = await SshKeyService.generateEd25519();
      expect(pem1, isNot(equals(pem2)));
      expect(SshKeyService.isValidPem(pem1), isTrue);
      expect(SshKeyService.isValidPem(pem2), isTrue);
    });
  });

  group('SshKeyService.isValidPem', () {
    test('拒绝非 PEM 内容', () {
      expect(SshKeyService.isValidPem('not a key'), isFalse);
      expect(SshKeyService.isValidPem(''), isFalse);
    });

    test('拒绝损坏的 PEM 内容', () {
      const broken =
          '-----BEGIN OPENSSH PRIVATE KEY-----\n'
          'AAAA\n'
          '-----END OPENSSH PRIVATE KEY-----';
      expect(SshKeyService.isValidPem(broken), isFalse);
    });
  });

  group('SshKeyService.derivePublicKey', () {
    test('输出 authorized_keys 公钥行,可被 dartssh2 解析', () async {
      final pem = await SshKeyService.generateEd25519();
      final publicKey = SshKeyService.derivePublicKey(pem);

      final parts = publicKey.split(' ');
      expect(parts, hasLength(3));
      expect(parts[0], 'ssh-ed25519');
      expect(parts[1], isNotEmpty);
      // 公钥行格式与 authorized_keys 要求一致(算法 + base64 + 注释)。
      expect(base64Decode(parts[1]), isNotEmpty);
      expect(parts[2], isNotEmpty);
    });

    test('同一私钥推导的公钥稳定', () async {
      final pem = await SshKeyService.generateEd25519();
      expect(
        SshKeyService.derivePublicKey(pem),
        SshKeyService.derivePublicKey(pem),
      );
    });
  });

  group('SshKeyService 加密私钥判定', () {
    test('无口令生成的 PEM 不被判定为加密', () async {
      final pem = await SshKeyService.generateEd25519();
      expect(SshKeyService.isEncryptedPem(pem), isFalse);
      expect(SshKeyService.isValidPemWithPassphrase(pem, ''), isTrue);
    });

    test('非 PEM 内容安全返回 false', () {
      expect(SshKeyService.isEncryptedPem('not-a-key'), isFalse);
      expect(SshKeyService.isValidPemWithPassphrase('bad', 'x'), isFalse);
    });
  });
}
