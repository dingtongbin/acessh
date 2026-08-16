// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:acessh/core/security/secrets_cipher.dart';
import 'package:acessh/features/device/application/device_controller.dart';
import 'package:acessh/features/device/data/device_repository.dart';
import 'package:acessh/features/device/domain/auth_method.dart';
import 'package:acessh/features/device/domain/connection_type.dart';
import 'package:acessh/features/device/domain/device.dart';
import 'package:acessh/features/script/application/script_controller.dart';
import 'package:acessh/features/script/data/script_file_repository.dart';
import 'package:acessh/features/settings/application/app_settings.dart';
import 'package:acessh/features/shell/presentation/shell_screen.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 测试用固定密钥的加密器(避免访问真实主密钥文件)。
final SecretsCipher testCipher = SecretsCipher(
  Future.value(SecretKey(List<int>.filled(32, 6))),
);

Device buildDevice({
  required String name,
  String folder = '',
  String host = '10.0.0.1',
  ConnectionType type = ConnectionType.ssh,
}) {
  return Device(
    name: name,
    type: type,
    host: host,
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
    folder: folder,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceController deviceController;
  late ScriptController scriptController;
  late Directory sessionsRoot;
  late Directory keysRoot;
  late Directory scriptsRoot;

  setUp(() async {
    sessionsRoot = await Directory.systemTemp.createTemp('acessh_home_sess_');
    keysRoot = await Directory.systemTemp.createTemp('acessh_home_keys_');
    scriptsRoot = await Directory.systemTemp.createTemp('acessh_home_script_');
    deviceController = DeviceController(
      DeviceRepository(
        directory: sessionsRoot.path,
        keysDirectory: keysRoot.path,
        cipher: testCipher,
      ),
    );
    scriptController = ScriptController(
      ScriptFileRepository(root: scriptsRoot),
    );
    await deviceController.load();
    await scriptController.load();
  });

  tearDown(() async {
    for (final dir in [sessionsRoot, keysRoot, scriptsRoot]) {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
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

  testWidgets('不支持类型设备在列表标注,点击仅提示不连接', (tester) async {
    final vncDevice = buildDevice(
      name: '远程桌面',
      type: ConnectionType.vnc,
      host: '10.0.0.5',
    );
    // 真实文件 IO 必须在 runAsync 中执行(FakeAsync 下会挂起)。
    await tester.runAsync(() => deviceController.addDevice(vncDevice));
    await tester.pumpWidget(_buildApp(deviceController, scriptController));
    await tester.pumpAndSettle();

    // 列表展示类型与"移动端暂不支持"标注。
    expect(find.text('远程桌面'), findsOneWidget);
    expect(find.text('VNC'), findsOneWidget);
    expect(find.text('移动端暂不支持'), findsOneWidget);

    // 点击条目:弹出提示,不进入连接流程。
    await tester.tap(find.text('远程桌面'));
    await tester.pump();
    expect(find.text('移动端暂不支持 VNC 类型连接'), findsOneWidget);

    // 等待 SnackBar 自动消失,避免测试结束时残留计时器。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('设备按文件夹分组展示,根目录组排最前', (tester) async {
    await tester.runAsync(() async {
      await deviceController.addDevice(buildDevice(name: '根设备'));
      await deviceController.addFolder('生产');
      await deviceController.addDevice(
        buildDevice(name: 'web-1', folder: '生产'),
      );
    });
    await tester.pumpWidget(_buildApp(deviceController, scriptController));
    await tester.pumpAndSettle();

    // 文件夹头与组内设备均可见。
    expect(find.text('生产'), findsOneWidget);
    expect(find.text('1 台设备'), findsOneWidget);
    expect(find.text('web-1'), findsOneWidget);
    expect(find.text('根设备'), findsOneWidget);

    // 根设备显示在文件夹头之前(列表顺序)。
    final rootY = tester.getTopLeft(find.text('根设备')).dy;
    final folderY = tester.getTopLeft(find.text('生产')).dy;
    expect(rootY, lessThan(folderY));
  });

  testWidgets('点击文件夹头折叠/展开组内设备', (tester) async {
    await tester.runAsync(() async {
      await deviceController.addFolder('生产');
      await deviceController.addDevice(
        buildDevice(name: 'web-1', folder: '生产'),
      );
    });
    await tester.pumpWidget(_buildApp(deviceController, scriptController));
    await tester.pumpAndSettle();

    // 折叠:组内设备隐藏,文件夹头保留。
    await tester.tap(find.text('生产'));
    await tester.pumpAndSettle();
    expect(find.text('web-1'), findsNothing);
    expect(find.text('生产'), findsOneWidget);

    // 展开:设备恢复显示。
    await tester.tap(find.text('生产'));
    await tester.pumpAndSettle();
    expect(find.text('web-1'), findsOneWidget);
  });

  testWidgets('搜索时平铺显示设备并附加文件夹前缀', (tester) async {
    await tester.runAsync(() async {
      await deviceController.addFolder('生产');
      await deviceController.addDevice(
        buildDevice(name: 'web-1', folder: '生产'),
      );
      await deviceController.addDevice(buildDevice(name: 'db-1'));
    });
    await tester.pumpWidget(_buildApp(deviceController, scriptController));
    await tester.pumpAndSettle();

    deviceController.setKeyword('web');
    await tester.pumpAndSettle();

    // 搜索时平铺:文件夹头不显示,命中设备带 [生产] 前缀。
    expect(find.text('生产'), findsNothing);
    expect(find.textContaining('[生产]'), findsOneWidget);
    expect(find.text('db-1'), findsNothing);
  });

  testWidgets('新建文件夹:保留名 keys 被拦截,合法名创建成功', (tester) async {
    await tester.pumpWidget(_buildApp(deviceController, scriptController));
    await tester.pumpAndSettle();

    // 点新建文件夹按钮 → 对话框出现。
    await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
    await tester.pumpAndSettle();
    expect(find.text('新建文件夹'), findsOneWidget);

    // 输入保留名 keys → 确定 → 拦截提示,对话框不关闭。
    await tester.enterText(find.byType(TextField).last, 'keys');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('不可创建该文件夹'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    // 取消关闭对话框。
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // 合法名创建(runAsync 中发起真实 IO),列表出现文件夹头。
    await tester.runAsync(() => deviceController.addFolder('生产'));
    await tester.pumpAndSettle();
    expect(find.text('生产'), findsOneWidget);
    expect(find.text('0 台设备'), findsOneWidget);
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
