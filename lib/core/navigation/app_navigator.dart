// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

/// 全局导航 key:供非 UI 层(如连接会话的指纹确认弹窗)使用。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
