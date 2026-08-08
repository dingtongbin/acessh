// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

/// 连接过渡窗口:连接期间展示,不可通过点击遮罩关闭。
class ConnectingDialog extends StatelessWidget {
  /// 创建连接过渡窗口。
  const ConnectingDialog({
    required this.deviceName,
    required this.host,
    required this.port,
    super.key,
  });

  /// 设备会话名。
  final String deviceName;

  /// 主机地址。
  final String host;

  /// 端口。
  final int port;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('正在连接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(deviceName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('$host:$port', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
