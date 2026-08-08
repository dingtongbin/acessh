// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/foundation.dart';

/// 统一日志组件,禁止在业务代码中直接使用 [print] 调试输出。
class AppLogger {
  const AppLogger._();

  /// 记录错误级别日志。
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[acessh][E] $message${error == null ? '' : '\n$error'}');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }

  /// 记录调试级别日志。
  static void d(String message) {
    debugPrint('[acessh][D] $message');
  }
}
