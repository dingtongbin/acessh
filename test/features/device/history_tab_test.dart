// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:acessh/features/connection/data/connection_record_repository.dart';
import 'package:acessh/features/device/presentation/history_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late ConnectionRecordRepository repository;

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
    repository = ConnectionRecordRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('空记录时展示空状态提示', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HistoryTab(repository: repository)),
      ),
    );
    // 数据库查询是真实异步,需在 runAsync 中等待其完成后再刷新帧。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('暂无连接记录,下拉刷新'), findsOneWidget);
  });

  testWidgets('有记录时展示设备名与成败状态', (tester) async {
    // sqflite 的异步在 FakeAsync 之外执行,必须用 runAsync 包裹。
    await tester.runAsync(() async {
      final successId = await repository.recordStart(
        deviceName: '测试机',
        deviceType: 'ssh',
      );
      await repository.recordEnd(recordId: successId, success: true);
      final failedId = await repository.recordStart(
        deviceName: '旧设备',
        deviceType: 'telnet',
      );
      await repository.recordEnd(recordId: failedId, success: false);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HistoryTab(repository: repository)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('测试机'), findsOneWidget);
    expect(find.text('旧设备'), findsOneWidget);
    expect(find.text('成功'), findsOneWidget);
    expect(find.text('失败'), findsOneWidget);
  });
}
