// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'app/app.dart';

/// 应用入口,仅负责初始化与引导,业务逻辑一律不放在这里。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AcesshApp());
}
