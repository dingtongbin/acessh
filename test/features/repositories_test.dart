// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:acessh/features/connection/data/connection_record_repository.dart';
import 'package:acessh/features/device/data/device_repository.dart';
import 'package:acessh/features/device/domain/auth_method.dart';
import 'package:acessh/features/device/domain/connection_type.dart';
import 'package:acessh/features/device/domain/device.dart';
import 'package:acessh/features/device/domain/device_sort_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Device buildDevice({String? name, String? host}) {
  return Device(
    name: name ?? '测试机',
    type: ConnectionType.ssh,
    host: host ?? '106.12.90.186',
    port: 22,
    username: 'root',
    password: 'secret',
    authMethod: AuthMethod.password,
    privateKey: '',
    privateKeyPassphrase: '',
    hostKey: '',
    baudRate: 115200,
    note: '',
    tag: '',
    openCount: 0,
    lastConnectedAt: null,
    createdAt: 1,
    updatedAt: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE devices (
              name TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              host TEXT NOT NULL,
              port INTEGER NOT NULL,
              username TEXT NOT NULL DEFAULT '',
              password TEXT NOT NULL DEFAULT '',
              auth_method TEXT NOT NULL DEFAULT 'password',
              private_key TEXT NOT NULL DEFAULT '',
              private_key_passphrase TEXT NOT NULL DEFAULT '',
              host_key TEXT NOT NULL DEFAULT '',
              baud_rate INTEGER NOT NULL DEFAULT 115200,
              open_count INTEGER NOT NULL DEFAULT 0,
              last_connected_at INTEGER,
              note TEXT NOT NULL DEFAULT '',
              tag TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE connection_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              device_name TEXT NOT NULL,
              device_type TEXT NOT NULL,
              result TEXT NOT NULL,
              connected_at INTEGER NOT NULL,
              disconnected_at INTEGER
            )
          ''');
        },
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('DeviceRepository', () {
    test('插入后可按主键查询,会话名唯一', () async {
      final repository = DeviceRepository(database);
      await repository.insert(buildDevice());
      final found = await repository.queryByName('测试机');
      expect(found, isNotNull);
      expect(found!.host, '106.12.90.186');

      // 重名插入抛出友好错误,而非数据库原始异常。
      await expectLater(
        repository.insert(buildDevice()),
        throwsA(isA<StateError>()),
      );
    });

    test('更新与删除', () async {
      final repository = DeviceRepository(database);
      await repository.insert(buildDevice());
      final updated = buildDevice().copyWith(host: '10.0.0.1');
      await repository.update(updated);
      expect((await repository.queryByName('测试机'))!.host, '10.0.0.1');

      await repository.delete('测试机');
      expect(await repository.queryByName('测试机'), isNull);
    });

    test('recordOpened 增加打开次数并更新最近登录时间', () async {
      final repository = DeviceRepository(database);
      await repository.insert(buildDevice());
      await repository.recordOpened('测试机');
      final found = await repository.queryByName('测试机');
      expect(found!.openCount, 1);
      expect(found.lastConnectedAt, isNotNull);
    });

    test('queryAll 支持按字段与方向排序', () async {
      final repository = DeviceRepository(database);
      final a = buildDevice(name: 'a', host: '1.1.1.1');
      final b = buildDevice(name: 'b', host: '2.2.2.2');
      await repository.insert(a);
      await repository.insert(b);
      await repository.recordOpened('a');

      final byOpenDesc = await repository.queryAll(
        sortField: DeviceSortField.openCount,
        direction: SortDirection.descending,
      );
      expect(byOpenDesc.first.name, 'a');

      final byOpenAsc = await repository.queryAll(
        sortField: DeviceSortField.openCount,
        direction: SortDirection.ascending,
      );
      expect(byOpenAsc.first.name, 'b');
    });

    test('search 支持模糊匹配主机与名称', () async {
      final repository = DeviceRepository(database);
      await repository.insert(buildDevice(name: '生产', host: '10.0.0.1'));
      await repository.insert(buildDevice(name: '测试', host: '106.12.90.186'));

      final byHost = await repository.search('106.12');
      expect(byHost.single.name, '测试');

      final byName = await repository.search('生产');
      expect(byName.single.host, '10.0.0.1');

      expect(await repository.search('不存在的'), isEmpty);
    });
  });

  group('ConnectionRecordRepository', () {
    test('记录开始与结束结果', () async {
      final repository = ConnectionRecordRepository(database);
      final id = await repository.recordStart(
        deviceName: '测试机',
        deviceType: 'ssh',
      );
      await repository.recordEnd(recordId: id, success: true);
      final records = await repository.queryRecent();
      expect(records.single.isSuccess, isTrue);
      expect(records.single.deviceName, '测试机');
    });

    test('失败记录与时间戳', () async {
      final repository = ConnectionRecordRepository(database);
      final id = await repository.recordStart(
        deviceName: '测试机',
        deviceType: 'ssh',
      );
      await repository.recordEnd(recordId: id, success: false);
      final records = await repository.queryRecent();
      expect(records.single.isSuccess, isFalse);
    });
  });
}
