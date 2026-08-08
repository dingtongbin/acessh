// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:kterm/kterm.dart';

/// 构建 kterm 终端主题。
///
/// 深色主题为黑底、浅色主题为白底,前景色可由用户设置覆盖;
/// 文本颜色与背景颜色可整体应用透明度(0-1,1 为不透明)。
class TerminalThemeBuilder {
  const TerminalThemeBuilder._();

  /// 构建终端主题。
  static TerminalTheme build({
    required bool dark,
    required Color foreground,
    double opacity = 1,
  }) {
    final background = dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final fg = foreground.withValues(alpha: opacity);
    final bg = background.withValues(alpha: opacity);
    final palette = dark ? _darkPalette : _lightPalette;
    return TerminalTheme(
      cursor: const Color(0xFFAAAAAA),
      selection: const Color(0x55555555),
      foreground: fg,
      background: bg,
      black: palette.black,
      red: palette.red,
      green: palette.green,
      yellow: palette.yellow,
      blue: palette.blue,
      magenta: palette.magenta,
      cyan: palette.cyan,
      white: palette.white,
      brightBlack: palette.brightBlack,
      brightRed: palette.brightRed,
      brightGreen: palette.brightGreen,
      brightYellow: palette.brightYellow,
      brightBlue: palette.brightBlue,
      brightMagenta: palette.brightMagenta,
      brightCyan: palette.brightCyan,
      brightWhite: palette.brightWhite,
      searchHitBackground: const Color(0xFFFFFF2B),
      searchHitBackgroundCurrent: const Color(0xFF31FF26),
      searchHitForeground: const Color(0xFF000000),
    );
  }

  /// 深色主题 16 色调色板。
  static const _Palette _darkPalette = _Palette(
    black: Color(0xFF000000),
    red: Color(0xFFCD3131),
    green: Color(0xFF0DBC79),
    yellow: Color(0xFFE5E510),
    blue: Color(0xFF2472C8),
    magenta: Color(0xFFBC3FBC),
    cyan: Color(0xFF11A8CD),
    white: Color(0xFFE5E5E5),
    brightBlack: Color(0xFF666666),
    brightRed: Color(0xFFF14C4C),
    brightGreen: Color(0xFF23D18B),
    brightYellow: Color(0xFFF5F543),
    brightBlue: Color(0xFF3B8EEA),
    brightMagenta: Color(0xFFD670D6),
    brightCyan: Color(0xFF29B8DB),
    brightWhite: Color(0xFFFFFFFF),
  );

  /// 浅色主题 16 色调色板。
  static const _Palette _lightPalette = _Palette(
    black: Color(0xFF000000),
    red: Color(0xFFCC0000),
    green: Color(0xFF00A500),
    yellow: Color(0xFF999900),
    blue: Color(0xFF0000D2),
    magenta: Color(0xFFB000B0),
    cyan: Color(0xFF00A6B2),
    white: Color(0xFF666666),
    brightBlack: Color(0xFF808080),
    brightRed: Color(0xFFFF0000),
    brightGreen: Color(0xFF00FF00),
    brightYellow: Color(0xFFFFFF00),
    brightBlue: Color(0xFF0000FF),
    brightMagenta: Color(0xFFFF00FF),
    brightCyan: Color(0xFF00FFFF),
    brightWhite: Color(0xFFFFFFFF),
  );
}

/// 16 色调色板。
class _Palette {
  /// 创建调色板。
  const _Palette({
    required this.black,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.magenta,
    required this.cyan,
    required this.white,
    required this.brightBlack,
    required this.brightRed,
    required this.brightGreen,
    required this.brightYellow,
    required this.brightBlue,
    required this.brightMagenta,
    required this.brightCyan,
    required this.brightWhite,
  });

  final Color black;
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color magenta;
  final Color cyan;
  final Color white;
  final Color brightBlack;
  final Color brightRed;
  final Color brightGreen;
  final Color brightYellow;
  final Color brightBlue;
  final Color brightMagenta;
  final Color brightCyan;
  final Color brightWhite;
}
