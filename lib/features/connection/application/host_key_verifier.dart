// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../device/data/device_repository.dart';
import '../../device/domain/device.dart';

/// SSH 主机指纹验证处理器:首次连接弹窗确认保存,
/// 指纹不一致时提示用户选择继续或取消。
class HostKeyVerifier {
  /// 创建指纹验证器。
  HostKeyVerifier({required this.device});

  /// 目标设备。
  final Device device;

  /// 验证主机指纹,返回是否接受连接。
  ///
  /// [fingerprint] 为 OpenSSH 格式(SHA256:xxx)。
  Future<bool> verify(String fingerprint) async {
    final stored = device.hostKey;
    if (stored.isEmpty) {
      return _confirmFirstConnection(fingerprint);
    }
    if (stored == fingerprint) {
      return true;
    }
    return _confirmMismatch(stored, fingerprint);
  }

  /// 首次连接确认弹窗;确认后保存指纹。
  Future<bool> _confirmFirstConnection(String fingerprint) async {
    final accepted = await _showDialog(
      title: '首次连接确认',
      content:
          '${device.name} 的主机指纹:\n\n$fingerprint\n\n'
          '是否信任该主机并继续连接?',
      confirmText: '信任并连接',
    );
    if (accepted) {
      await DeviceRepository().saveHostKey(device.name, fingerprint);
    }
    return accepted;
  }

  /// 指纹不一致提示弹窗。
  Future<bool> _confirmMismatch(String stored, String fingerprint) async {
    return _showDialog(
      title: '主机指纹不一致',
      content:
          '${device.name} 的主机指纹与已保存的不一致!\n\n'
          '已保存:$stored\n当前:$fingerprint\n\n'
          '可能遭受中间人攻击,请谨慎决定。',
      confirmText: '仍然连接',
    );
  }

  /// 通过全局导航展示确认弹窗。
  Future<bool> _showDialog({
    required String title,
    required String content,
    required String confirmText,
  }) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      // 无可用导航上下文(如后台连接)时默认拒绝,避免静默接受。
      return false;
    }
    final result = await showDialog<bool>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
