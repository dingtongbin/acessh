// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:acessh/features/device/application/device_transfer_service.dart';
import 'package:acessh/features/device/domain/auth_method.dart';
import 'package:acessh/features/device/domain/connection_type.dart';
import 'package:acessh/features/device/domain/device.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

Device buildDevice(String name) {
  return Device(
    name: name,
    type: ConnectionType.ssh,
    host: '10.0.0.$name.length',
    port: 22,
    username: 'root',
    password: 'secret',
    authMethod: AuthMethod.password,
    privateKey: '',
    privateKeyPassphrase: '',
    hostKey: '',
    baudRate: 115200,
    note: '备注$name',
    tag: '生产',
    openCount: 3,
    lastConnectedAt: 1234567890,
    createdAt: 1,
    updatedAt: 2,
  );
}

void main() {
  group('DeviceTransferService', () {
    test('导出加密后可解密还原全部字段', () async {
      final devices = [buildDevice('A'), buildDevice('B')];
      final encrypted = await DeviceTransferService.encryptDevices(
        devices,
        'password123',
      );

      expect(encrypted, contains('acessh-devices-v1'));

      final decrypted = await DeviceTransferService.decryptDevices(
        encrypted,
        'password123',
      );
      expect(decrypted, hasLength(2));
      expect(decrypted[0].name, 'A');
      expect(decrypted[0].password, 'secret');
      expect(decrypted[0].privateKey, '');
      expect(decrypted[0].hostKey, '');
      expect(decrypted[0].tag, '生产');
      expect(decrypted[0].openCount, 3);
      expect(decrypted[0].lastConnectedAt, 1234567890);
    });

    test('错误密码解密失败', () async {
      final devices = [buildDevice('A')];
      final encrypted = await DeviceTransferService.encryptDevices(
        devices,
        'right-password',
      );
      await expectLater(
        DeviceTransferService.decryptDevices(encrypted, 'wrong-password'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('同一密码每次导出密文不同(随机盐)', () async {
      final devices = [buildDevice('A')];
      final a = await DeviceTransferService.encryptDevices(devices, 'pw');
      final b = await DeviceTransferService.encryptDevices(devices, 'pw');
      expect(a, isNot(equals(b)));
    });

    test('拒绝非 acessh 格式内容', () async {
      await expectLater(
        DeviceTransferService.decryptDevices('{"format":"other"}', 'pw'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
