// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

/// 应用级颜色常量,集中管理避免散落魔法色值。
abstract final class AppColors {
  /// 品牌主色,安卓风格 Material 3 蓝绿色。
  static const Color primary = Color(0xFF006A6A);

  /// 终端深色背景,与主界面形成对比。
  static const Color terminalBackground = Color(0xFF10151A);

  /// 终端浅色背景。
  static const Color terminalBackgroundLight = Color(0xFFF7F7F7);
}

/// 构建安卓风格(Material 3)的全局主题。
class AppTheme {
  const AppTheme._();

  /// 返回浅色/深色随系统切换的 Material 3 主题;
  /// [seedColor] 为主题色(应用主题设置中可配置)。
  static ThemeData create(Brightness brightness, {Color? seedColor}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? AppColors.primary,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }
}
