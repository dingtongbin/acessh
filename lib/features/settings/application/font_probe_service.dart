// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

/// 系统字体探测:读取 Android 系统字体清单(/system/fonts/fonts.xml),
/// 在下拉列表触发时扫描可用等宽字体;非 Android 平台回退候选列表。
class FontProbeService {
  const FontProbeService._();

  /// 兜底候选等宽字体。
  static const List<String> _fallbackFonts = [
    'monospace',
    'Roboto Mono',
    'Menlo',
    'Consolas',
    'Courier New',
    'Liberation Mono',
    'Noto Sans Mono CJK SC',
    'Droid Sans Mono',
    'sans-serif',
  ];

  /// 探测系统可用字体列表(下拉触发时调用)。
  ///
  /// Android 上解析 /system/fonts/fonts.xml 提取字体族名;
  /// 解析失败或非 Android 平台时返回兜底候选列表。
  static Future<List<String>> probeAvailableFonts() async {
    if (Platform.isAndroid) {
      try {
        final xml = await _readSystemFonts();
        final families = _parseFontFamilies(xml);
        if (families.isNotEmpty) {
          final result = <String>['monospace', ...families];
          return result.toSet().toList();
        }
      } on Object {
        // 读取失败时回退候选列表。
      }
    }
    return _fallbackFonts;
  }

  /// 读取系统字体清单。
  static Future<String> _readSystemFonts() async {
    final file = File('/system/fonts/fonts.xml');
    return file.readAsString();
  }

  /// 从 fonts.xml 提取 `family` 标签的 `name` 属性。
  static List<String> _parseFontFamilies(String xml) {
    final families = <String>[];
    final regex = RegExp(r'<family\s+name="([^"]+)"');
    for (final match in regex.allMatches(xml)) {
      final name = match.group(1);
      if (name != null && name.isNotEmpty && !families.contains(name)) {
        families.add(name);
      }
    }
    return families;
  }
}
