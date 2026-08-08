// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/database/app_database.dart';
import '../core/logging/app_logger.dart';
import '../core/navigation/app_navigator.dart';
import '../features/connection/application/session_manager.dart';
import '../features/device/application/device_controller.dart';
import '../features/script/application/script_controller.dart';
import '../features/settings/application/app_settings.dart';
import '../features/settings/presentation/app_lock_screen.dart';
import '../features/settings/presentation/license_screen.dart';
import '../features/shell/presentation/shell_screen.dart';
import '../features/terminal/application/input_modifier_controller.dart';
import 'theme.dart';

/// 应用根 Widget,负责全局初始化、主题、许可/应用锁门控与状态注入。
class AcesshApp extends StatefulWidget {
  /// 创建应用根组件。
  const AcesshApp({super.key});

  @override
  State<AcesshApp> createState() => _AcesshAppState();
}

class _AcesshAppState extends State<AcesshApp> {
  late final Future<void> _initFuture = _init();

  /// 初始化数据库、系统目录与各控制器。
  Future<void> _init() async {
    await AppDatabase.instance.open();
    await AppSettings.instance.load();
    await DeviceController.instance.load();
    await ScriptController.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          AppLogger.e('应用初始化失败', snapshot.error, snapshot.stackTrace);
          return MaterialApp(
            title: 'acessh',
            theme: AppTheme.create(Brightness.light),
            darkTheme: AppTheme.create(Brightness.dark),
            home: Scaffold(
              body: Center(child: Text('初始化失败:${snapshot.error}')),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'acessh',
            theme: AppTheme.create(Brightness.light),
            darkTheme: AppTheme.create(Brightness.dark),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: AppSettings.instance),
            ChangeNotifierProvider.value(value: DeviceController.instance),
            ChangeNotifierProvider.value(value: ScriptController.instance),
            ChangeNotifierProvider.value(value: SessionManager.instance),
            ChangeNotifierProvider.value(
              value: InputModifierController.instance,
            ),
          ],
          child: ListenableBuilder(
            listenable: AppSettings.instance,
            builder: (context, _) {
              final settings = AppSettings.instance;
              return MaterialApp(
                navigatorKey: appNavigatorKey,
                title: 'acessh',
                theme: AppTheme.create(
                  Brightness.light,
                  seedColor: settings.themeColor,
                ),
                darkTheme: AppTheme.create(
                  Brightness.dark,
                  seedColor: settings.themeColor,
                ),
                themeMode: switch (settings.themeMode) {
                  AppThemeMode.system => ThemeMode.system,
                  AppThemeMode.light => ThemeMode.light,
                  AppThemeMode.dark => ThemeMode.dark,
                },
                home: const AppGate(),
              );
            },
          ),
        );
      },
    );
  }
}

/// 应用门控:首次进入先同意许可,再通过应用锁,最后进入主界面。
class AppGate extends StatefulWidget {
  /// 创建应用门控。
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  /// 本次启动是否已通过应用锁验证(仅冷启动校验一次)。
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    if (!settings.licenseAccepted) {
      return LicenseScreen(onAccepted: () => setState(() {}));
    }
    if (settings.appLockEnabled &&
        settings.hasAppLockCredential &&
        !_unlocked) {
      return AppLockScreen(onUnlocked: () => setState(() => _unlocked = true));
    }
    return const ShellScreen();
  }
}
