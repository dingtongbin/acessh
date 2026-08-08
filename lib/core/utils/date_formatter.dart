// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// 时间展示工具。
abstract final class DateFormatter {
  const DateFormatter._();

  /// 将毫秒时间戳格式化为 "yyyy-MM-dd HH:mm"。
  static String format(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }

  /// 将毫秒时间戳格式化为 "yyyy-MM-dd HH:mm"。
  static String formatMillis(int? millis) {
    if (millis == null) {
      return '-';
    }
    return format(DateTime.fromMillisecondsSinceEpoch(millis));
  }
}
