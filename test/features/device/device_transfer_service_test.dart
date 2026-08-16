// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';
import 'dart:typed_data';

import 'package:acessh/features/connection/domain/stored_key.dart';
import 'package:acessh/features/device/application/device_transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 合规导出密码:8 位,大写/小写/数字/符号四类。
  const password = 'Aa1!Aa1!';

  final sessionEntry = (
    entryPath: '生产/web-1.toml',
    bytes: Uint8List.fromList(
      utf8.encode('name = "web-1"\ntype = "ssh"\nhost = "1.1.1.1"\n'),
    ),
  );
  final rootSessionEntry = (
    entryPath: '根设备.toml',
    bytes: Uint8List.fromList(utf8.encode('name = "根设备"\ntype = "telnet"\n')),
  );
  final key = StoredKey(
    name: 'Ed25519-20260816-1200',
    privateKey: 'pem-content',
    passphrase: 'pass',
    createdAt: 123,
  );

  group('ExportPasswordPolicy', () {
    test('长度限制 8~64 位', () {
      expect(ExportPasswordPolicy.validate('Aa1!Aa'), isNotNull);
      expect(ExportPasswordPolicy.validate('Aa1!Aa1!'), isNull);
      expect(
        ExportPasswordPolicy.validate('Aa1!' * 17),
        isNotNull, // 68 位超长。
      );
    });

    test('四类字符至少三类', () {
      // 小写 + 数字 2 类 → 不合规。
      expect(ExportPasswordPolicy.validate('aaaa1111'), isNotNull);
      // 小写 + 数字 + 大写 3 类 → 合规。
      expect(ExportPasswordPolicy.validate('aaaa1111AAAA'), isNull);
      // 四类全含 → 合规。
      expect(ExportPasswordPolicy.validate('Aa1!Aa1!'), isNull);
    });

    test('类别统计与缺失提示', () {
      expect(ExportPasswordPolicy.categoryCount('Ab1!'), 4);
      expect(ExportPasswordPolicy.categoryCount('aaaa'), 1);
      expect(
        ExportPasswordPolicy.missingCategories('aaaa1111'),
        containsAll(['大写字母', '符号']),
      );
    });
  });

  group('DeviceTransferService 导出/导入', () {
    test('导出包布局:魔数 + 16 字节盐 + 12 字节 nonce + 密文', () async {
      final bytes = await DeviceTransferService.exportPackage(
        sessionFiles: [sessionEntry],
        keys: [key],
        password: password,
      );
      expect(utf8.decode(bytes.sublist(0, 8)), DeviceTransferService.magic);
      expect(bytes.length, greaterThan(8 + 16 + 12));
      // 同一密码两次导出密文不同(盐与 nonce 随机)。
      final bytes2 = await DeviceTransferService.exportPackage(
        sessionFiles: [sessionEntry],
        keys: [key],
        password: password,
      );
      expect(bytes, isNot(equals(bytes2)));
    });

    test('往返:会话字节原样、密钥字段完整还原', () async {
      final bytes = await DeviceTransferService.exportPackage(
        sessionFiles: [sessionEntry, rootSessionEntry],
        keys: [key],
        password: password,
      );
      final pkg = await DeviceTransferService.importPackage(
        bytes: bytes,
        password: password,
      );

      // 会话:文件夹推导 + 原始字节一致(原样携带,不做任何改写)。
      expect(pkg.sessions, hasLength(2));
      final folderSession = pkg.sessions.firstWhere(
        (entry) => entry.name == 'web-1',
      );
      expect(folderSession.folder, '生产');
      expect(folderSession.bytes, sessionEntry.bytes);
      final rootSession = pkg.sessions.firstWhere(
        (entry) => entry.name == '根设备',
      );
      expect(rootSession.folder, '');
      expect(rootSession.bytes, rootSessionEntry.bytes);

      // 密钥:包内为明文,字段完整。
      expect(pkg.keys.single.name, 'Ed25519-20260816-1200');
      expect(pkg.keys.single.privateKey, 'pem-content');
      expect(pkg.keys.single.passphrase, 'pass');
      expect(pkg.keys.single.createdAt, 123);
    });

    test('包内密钥条目是明文 JSON,不含本地 enc 前缀', () async {
      // 若包内套用本地主密钥加密,导入方(另一台机器)将无法解密;
      // 因此导入得到的私钥/口令必须是明文原值。
      final bytes = await DeviceTransferService.exportPackage(
        sessionFiles: [sessionEntry],
        keys: [key],
        password: password,
      );
      final pkg = await DeviceTransferService.importPackage(
        bytes: bytes,
        password: password,
      );
      expect(pkg.keys.single.privateKey, isNot(contains('enc:v1:')));
      expect(pkg.keys.single.passphrase, isNot(contains('enc:v1:')));
      expect(pkg.keys.single.privateKey, 'pem-content');
    });

    test('密码错误 → StateError(密码错误或加密包已损坏)', () async {
      final bytes = await DeviceTransferService.exportPackage(
        sessionFiles: [sessionEntry],
        keys: const [],
        password: password,
      );
      await expectLater(
        DeviceTransferService.importPackage(
          bytes: bytes,
          password: 'Wrong123!',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('密码错误'),
          ),
        ),
      );
    });

    test('魔数被篡改 → FormatException(包已损坏)', () async {
      final bytes = await DeviceTransferService.exportPackage(
        sessionFiles: [sessionEntry],
        keys: const [],
        password: password,
      );
      bytes[0] = 0x58; // 改第一个魔数字节。
      await expectLater(
        DeviceTransferService.importPackage(bytes: bytes, password: password),
        throwsA(isA<FormatException>()),
      );
    });

    test('长度不足 → FormatException(包已损坏)', () async {
      await expectLater(
        DeviceTransferService.importPackage(
          bytes: Uint8List.fromList([1, 2, 3]),
          password: password,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('无会话仅密钥也可导出导入', () async {
      final bytes = await DeviceTransferService.exportPackage(
        sessionFiles: const [],
        keys: [key],
        password: password,
      );
      final pkg = await DeviceTransferService.importPackage(
        bytes: bytes,
        password: password,
      );
      expect(pkg.sessions, isEmpty);
      expect(pkg.keys.single.name, key.name);
    });
  });
}
