// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:acessh/features/device/domain/auth_method.dart';
import 'package:acessh/features/device/domain/connection_type.dart';
import 'package:acessh/features/device/domain/device.dart';
import 'package:flutter_test/flutter_test.dart';

Device buildDevice({
  String name = '测试机',
  ConnectionType type = ConnectionType.ssh,
  AuthMethod authMethod = AuthMethod.password,
  String privateKey = '',
  String privateKeyPassphrase = '',
  String? lastConnectedAt,
  int baudRate = 115200,
  String folder = '',
  String keyPath = '',
}) {
  return Device(
    name: name,
    type: type,
    host: '106.12.90.186',
    port: 22,
    username: 'root',
    password: 'secret',
    authMethod: authMethod,
    privateKey: privateKey,
    privateKeyPassphrase: privateKeyPassphrase,
    hostKey: 'SHA256:abc',
    baudRate: baudRate,
    note: '测试备注',
    tag: '生产',
    openCount: 3,
    lastConnectedAt: lastConnectedAt == null
        ? null
        : DateTime.parse(lastConnectedAt).millisecondsSinceEpoch,
    createdAt: DateTime(2026, 8, 16, 12).millisecondsSinceEpoch,
    updatedAt: DateTime(2026, 8, 16, 13).millisecondsSinceEpoch,
    folder: folder,
    keyPath: keyPath,
  );
}

void main() {
  group('toTomlMap 输出', () {
    test('SSH 密码认证:只写当前类型字段,时间为 ISO 字符串', () {
      final map = buildDevice().toTomlMap();
      expect(map['type'], 'ssh');
      expect(map['host'], '106.12.90.186');
      expect(map['port'], 22);
      expect(map['username'], 'root');
      expect(map['auth_mode'], 'password');
      expect(map['password'], 'secret');
      expect(map['created_at'], isA<String>());
      expect(DateTime.tryParse(map['created_at'] as String), isNotNull);
      expect(map['open_count'], 3);
      expect(map['host_key'], 'SHA256:abc');
      // 无 last_connected_at 时省略该键。
      expect(map.containsKey('last_connected_at'), isFalse);
    });

    test('SSH 私钥认证:auth_mode=key,写入 key_path,不含密码与明文私钥', () {
      final map = buildDevice(
        authMethod: AuthMethod.privateKey,
        privateKey: 'pem-content',
        privateKeyPassphrase: 'pass',
        keyPath: '/data/keys/Ed25519-20260816-1230.json',
      ).toTomlMap();
      expect(map['auth_mode'], 'key');
      expect(map['key_path'], '/data/keys/Ed25519-20260816-1230.json');
      expect(map.containsKey('password'), isFalse);
      // 口令随密钥 JSON 存储,不写入会话文件。
      expect(map.containsKey('key_passphrase'), isFalse);
      // 私钥明文不进 TOML。
      expect(map.containsValue('pem-content'), isFalse);
    });

    test('Telnet:host/port/username/password,无 auth_mode', () {
      final map = buildDevice(type: ConnectionType.telnet).toTomlMap();
      expect(map['host'], '106.12.90.186');
      expect(map['password'], 'secret');
      expect(map.containsKey('auth_mode'), isFalse);
      expect(map.containsKey('device_path'), isFalse);
    });

    test('串口:device_path 与 baud_rate,无 host/port/username/password', () {
      final map = buildDevice(type: ConnectionType.serial).toTomlMap();
      expect(map['device_path'], '106.12.90.186');
      expect(map['baud_rate'], 115200);
      expect(map.containsKey('host'), isFalse);
      expect(map.containsKey('port'), isFalse);
      expect(map.containsKey('username'), isFalse);
      expect(map.containsKey('password'), isFalse);
    });

    test('VNC(不支持类型):host/port/username/password', () {
      final map = buildDevice(type: ConnectionType.vnc).toTomlMap();
      expect(map['type'], 'vnc');
      expect(map['host'], '106.12.90.186');
      expect(map['port'], 22);
      expect(map['username'], 'root');
      expect(map['password'], 'secret');
    });

    test('unsupported 类型保留原始 type 字符串', () {
      final device = Device.fromTomlMap({
        'name': '神秘',
        'type': 'future-protocol',
        'host': '1.2.3.4',
      });
      expect(device.type, ConnectionType.unsupported);
      expect(device.originalType, 'future-protocol');
      expect(device.toTomlMap()['type'], 'future-protocol');
      expect(device.toMap()['type'], 'future-protocol');
    });

    test('folder 不写入 TOML,keyPath 不写入明文私钥', () {
      final map = buildDevice(folder: '生产').toTomlMap();
      expect(map.containsKey('folder'), isFalse);
    });
  });

  group('fromTomlMap 解析', () {
    test('宽松读取:缺键用默认值,未知键忽略', () {
      final device = Device.fromTomlMap({
        'name': '缺字段机',
        'type': 'ssh',
        'host': '10.0.0.1',
      });
      expect(device.name, '缺字段机');
      expect(device.port, 0);
      expect(device.username, '');
      expect(device.password, '');
      expect(device.authMethod, AuthMethod.password);
      expect(device.openCount, 0);
      expect(device.lastConnectedAt, isNull);
      expect(device.baudRate, 115200);
    });

    test('未知 type 归为 unsupported 并保留原始值', () {
      final device = Device.fromTomlMap({
        'name': '未知机',
        'type': 'some-new-type',
        'host': '1.1.1.1',
      });
      expect(device.type, ConnectionType.unsupported);
      expect(device.originalType, 'some-new-type');
      expect(device.isSupportedOnMobile, isFalse);
    });

    test('name 缺失时回退 fallbackName', () {
      final device = Device.fromTomlMap({
        'type': 'telnet',
        'host': '2.2.2.2',
      }, fallbackName: '文件名机');
      expect(device.name, '文件名机');
      // 文件名为空字符串时也回退。
      final empty = Device.fromTomlMap({
        'type': 'telnet',
        'host': '2.2.2.2',
        'name': '  ',
      }, fallbackName: '回退名');
      expect(empty.name, '回退名');
    });

    test('串口:device_path 映射到 host,缺 device_path 时回退 host 键', () {
      final device = Device.fromTomlMap({
        'name': '串口机',
        'type': 'serial',
        'device_path': '/dev/ttyUSB0',
        'baud_rate': 9600,
      });
      expect(device.host, '/dev/ttyUSB0');
      expect(device.baudRate, 9600);

      final legacy = Device.fromTomlMap({
        'name': '旧串口机',
        'type': 'serial',
        'host': '/dev/ttyS1',
      });
      expect(legacy.host, '/dev/ttyS1');
      expect(legacy.baudRate, 115200);
    });

    test('私钥认证:口令从注入参数读取,旧格式回退 key_passphrase', () {
      final device = Device.fromTomlMap(
        {
          'name': '密钥机',
          'type': 'ssh',
          'host': '1.1.1.1',
          'auth_mode': 'key',
          'password': '不应被读取',
        },
        privateKey: 'loaded-pem',
        privateKeyPassphrase: 'new-pass',
      );
      expect(device.authMethod, AuthMethod.privateKey);
      expect(device.privateKey, 'loaded-pem');
      expect(device.privateKeyPassphrase, 'new-pass');
      expect(device.password, '');

      // 旧格式:口令曾写在会话文件的 key_passphrase 字段。
      final legacy = Device.fromTomlMap({
        'name': '旧密钥机',
        'type': 'ssh',
        'host': '1.1.1.1',
        'auth_mode': 'key',
        'key_passphrase': 'old-pass',
      });
      expect(legacy.privateKeyPassphrase, 'old-pass');
    });

    test('时间 ISO 字符串解析为毫秒时间戳,无法解析时返回 null', () {
      final device = Device.fromTomlMap({
        'name': '时间机',
        'type': 'ssh',
        'host': '1.1.1.1',
        'created_at': '2026-08-16T12:00:00.000',
        'updated_at': '2026-08-16T13:00:00.000',
        'last_connected_at': '2026-08-16T14:00:00.000',
      });
      expect(
        device.createdAt,
        DateTime(2026, 8, 16, 12).millisecondsSinceEpoch,
      );
      expect(
        device.updatedAt,
        DateTime(2026, 8, 16, 13).millisecondsSinceEpoch,
      );
      expect(
        device.lastConnectedAt,
        DateTime(2026, 8, 16, 14).millisecondsSinceEpoch,
      );

      final broken = Device.fromTomlMap({
        'name': '坏时间机',
        'type': 'ssh',
        'host': '1.1.1.1',
        'created_at': '不是时间',
      });
      expect(broken.createdAt, 0);
      expect(broken.lastConnectedAt, isNull);
    });

    test('folder 与 key_path 注入', () {
      final device = Device.fromTomlMap({
        'name': '分组机',
        'type': 'ssh',
        'host': '1.1.1.1',
        'key_path': '/data/keys/x.json',
      }, folder: '生产');
      expect(device.folder, '生产');
      expect(device.keyPath, '/data/keys/x.json');
    });

    test('toTomlMap → fromTomlMap 往返字段一致', () {
      final original = buildDevice(
        authMethod: AuthMethod.privateKey,
        privateKey: 'pem',
        privateKeyPassphrase: 'pass',
        lastConnectedAt: '2026-08-16T14:30:00.000',
        folder: '生产',
        keyPath: '/keys/x.json',
      );
      final roundtrip = Device.fromTomlMap(
        original.toTomlMap(),
        folder: '生产',
        privateKey: 'pem',
        privateKeyPassphrase: 'pass',
      );
      expect(roundtrip.name, original.name);
      expect(roundtrip.type, original.type);
      expect(roundtrip.host, original.host);
      expect(roundtrip.port, original.port);
      expect(roundtrip.username, original.username);
      expect(roundtrip.authMethod, original.authMethod);
      expect(roundtrip.privateKey, original.privateKey);
      expect(roundtrip.privateKeyPassphrase, original.privateKeyPassphrase);
      expect(roundtrip.hostKey, original.hostKey);
      expect(roundtrip.note, original.note);
      expect(roundtrip.tag, original.tag);
      expect(roundtrip.openCount, original.openCount);
      expect(roundtrip.lastConnectedAt, original.lastConnectedAt);
      expect(roundtrip.createdAt, original.createdAt);
      expect(roundtrip.updatedAt, original.updatedAt);
      expect(roundtrip.folder, original.folder);
      expect(roundtrip.keyPath, original.keyPath);
    });
  });

  group('类型辅助属性', () {
    test('isSupportedOnMobile 仅 SSH/Telnet/串口为真', () {
      expect(ConnectionType.ssh.isSupportedOnMobile, isTrue);
      expect(ConnectionType.telnet.isSupportedOnMobile, isTrue);
      expect(ConnectionType.serial.isSupportedOnMobile, isTrue);
      expect(ConnectionType.sftp.isSupportedOnMobile, isFalse);
      expect(ConnectionType.vnc.isSupportedOnMobile, isFalse);
      expect(ConnectionType.rdp.isSupportedOnMobile, isFalse);
      expect(ConnectionType.x11.isSupportedOnMobile, isFalse);
      expect(ConnectionType.unsupported.isSupportedOnMobile, isFalse);
    });

    test('fromStorage 识别 AceShell 全部类型,未知值归 unsupported', () {
      expect(ConnectionType.fromStorage('ssh'), ConnectionType.ssh);
      expect(ConnectionType.fromStorage('telnet'), ConnectionType.telnet);
      expect(ConnectionType.fromStorage('serial'), ConnectionType.serial);
      expect(ConnectionType.fromStorage('sftp'), ConnectionType.sftp);
      expect(ConnectionType.fromStorage('vnc'), ConnectionType.vnc);
      expect(ConnectionType.fromStorage('rdp'), ConnectionType.rdp);
      expect(ConnectionType.fromStorage('x11'), ConnectionType.x11);
      expect(
        ConnectionType.fromStorage('unknown-x'),
        ConnectionType.unsupported,
      );
    });
  });
}
