// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';
import 'dart:io';

import 'package:acessh/core/security/secrets_cipher.dart';
import 'package:acessh/features/connection/data/ssh_key_repository.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory keysDir;
  late SshKeyRepository repository;

  final cipher = SecretsCipher(
    Future.value(SecretKey(List<int>.filled(32, 3))),
  );

  setUp(() async {
    keysDir = await Directory.systemTemp.createTemp('acessh_keys_');
    repository = SshKeyRepository(directory: keysDir.path, cipher: cipher);
  });

  tearDown(() async {
    if (keysDir.existsSync()) {
      await keysDir.delete(recursive: true);
    }
  });

  test('createKey 生成 JSON 文件,敏感字段加密存储', () async {
    final key = await repository.createKey(
      privateKey: 'pem-content',
      passphrase: 'pass',
    );
    expect(key.name, startsWith('Ed25519-'));
    expect(key.filePath, isNotEmpty);
    expect(await File(key.filePath).exists(), isTrue);

    // JSON 中私钥与口令为 enc:v1: 密文,不含明文。
    final json =
        jsonDecode(await File(key.filePath).readAsString())
            as Map<String, dynamic>;
    expect(json['private_key'], startsWith(SecretsCipher.prefix));
    expect(json['passphrase'], startsWith(SecretsCipher.prefix));
    expect(json['private_key'], isNot(contains('pem-content')));
    expect(json['passphrase'], isNot(contains('pass')));
    expect(json['created_at'], isA<int>());
  });

  test('同名时间创建的密钥自动追加序号,名称唯一', () async {
    final a = await repository.createKey(privateKey: 'a');
    final b = await repository.createKey(privateKey: 'b');
    // 同一分钟内创建时第二个名称追加 -2。
    expect(b.name, startsWith('${a.name}-'));
    expect(a.name, isNot(equals(b.name)));
  });

  test('loadKey 解密还原私钥与口令', () async {
    final key = await repository.createKey(
      privateKey: 'pem-content',
      passphrase: 'pass',
    );
    final loaded = await repository.loadKey(key.name);
    expect(loaded, isNotNull);
    expect(loaded!.privateKey, 'pem-content');
    expect(loaded.passphrase, 'pass');
    expect(loaded.filePath, key.filePath);

    expect(await repository.loadKey('不存在的'), isNull);
  });

  test('listKeys 按创建时间倒序,非 JSON 文件(master.key)被排除', () async {
    await repository.createKey(privateKey: 'first');
    await repository.createKey(privateKey: 'second');

    // 模拟主密钥文件:不应被列为密钥。
    await File(
      '${keysDir.path}${Platform.pathSeparator}master.key',
    ).writeAsString('00');

    final keys = await repository.listKeys();
    expect(keys, hasLength(2));
    expect(keys.first.createdAt, greaterThanOrEqualTo(keys.last.createdAt));
  });

  test('deleteKey 删除密钥文件', () async {
    final key = await repository.createKey(privateKey: 'x');
    await repository.deleteKey(key.name);
    expect(await repository.loadKey(key.name), isNull);
    expect(await File(key.filePath).exists(), isFalse);
  });

  test('空口令不加密存储,读取返回空串', () async {
    final key = await repository.createKey(privateKey: 'no-pass');
    final json =
        jsonDecode(await File(key.filePath).readAsString())
            as Map<String, dynamic>;
    expect(json['passphrase'], '');
    expect((await repository.loadKey(key.name))!.passphrase, '');
  });

  test('损坏的密钥文件被跳过', () async {
    await File(
      '${keysDir.path}${Platform.pathSeparator}broken.json',
    ).writeAsString('not-json');
    final keys = await repository.listKeys();
    expect(keys, isEmpty);
  });
}
