// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:acessh/features/device/application/device_controller.dart';
import 'package:acessh/features/device/data/device_repository.dart';
import 'package:acessh/features/script/application/script_controller.dart';
import 'package:acessh/features/script/data/script_file_repository.dart';
import 'package:acessh/features/settings/application/app_settings.dart';
import 'package:acessh/features/shell/presentation/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceController deviceController;
  late ScriptController scriptController;
  late Directory scriptsRoot;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
    scriptsRoot = await Directory.systemTemp.createTemp('acessh_home_test_');
    deviceController = DeviceController(DeviceRepository(database));
    scriptController = ScriptController(
      ScriptFileRepository(root: scriptsRoot),
    );
    await deviceController.load();
    await scriptController.load();
  });

  tearDown(() async {
    if (scriptsRoot.existsSync()) {
      await scriptsRoot.delete(recursive: true);
    }
  });

  /// 主页渲染契约:底部导航三项、内容区三个 Tab、默认设备列表。
  testWidgets('主页默认展示设备列表 Tab 与快速添加按钮', (tester) async {
    await tester.pumpWidget(_buildApp(deviceController, scriptController));
    await tester.pumpAndSettle();

    // IndexedStack 预构建全部页面,标题与导航标签会重复出现。
    expect(find.text('主页'), findsWidgets);
    expect(find.text('脚本'), findsWidgets);
    expect(find.text('设置'), findsWidgets);

    expect(find.text('设备列表'), findsOneWidget);
    expect(find.text('已连接'), findsOneWidget);
    expect(find.text('连接记录'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('底部导航可切换到设置页', (tester) async {
    await tester.pumpWidget(_buildApp(deviceController, scriptController));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('主题设置'), findsOneWidget);
    expect(find.text('应用锁设置'), findsOneWidget);
  });

  testWidgets('点击搜索按钮弹出搜索对话框', (tester) async {
    await tester.pumpWidget(_buildApp(deviceController, scriptController));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('搜索设备'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('底部导航脚本页展示脚本目录与新建入口', (tester) async {
    await tester.pumpWidget(_buildApp(deviceController, scriptController));
    await tester.pumpAndSettle();

    await tester.tap(find.text('脚本').last);
    await tester.pumpAndSettle();

    expect(find.text('脚本管理'), findsOneWidget);
    expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
  });
}

/// 构建带测试控制器的应用外壳。
Widget _buildApp(
  DeviceController deviceController,
  ScriptController scriptController,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: deviceController),
      ChangeNotifierProvider.value(value: scriptController),
      ChangeNotifierProvider.value(value: AppSettings.instance),
    ],
    child: const MaterialApp(home: ShellScreen()),
  );
}

/// 测试数据库建表(与 AppDatabase._onCreate 保持一致)。
Future<void> _onCreate(Database db, int version) async {
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
      baud_rate INTEGER NOT NULL DEFAULT 115200,
      open_count INTEGER NOT NULL DEFAULT 0,
      last_connected_at INTEGER,
      note TEXT NOT NULL DEFAULT '',
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
}
