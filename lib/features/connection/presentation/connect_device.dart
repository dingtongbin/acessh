// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../device/application/device_controller.dart';
import '../../device/domain/connection_type.dart';
import '../../device/domain/device.dart';
import '../../terminal/presentation/terminal_screen.dart';
import '../application/session_manager.dart';
import 'connecting_dialog.dart';

/// 建立到 [device] 的连接并进入终端页。
///
/// SSH 登录凭据不全时(未设置账户,或已保存账户但未保存密码),
/// 先弹出输入框收集凭据,可勾选记住;之后展示连接过渡窗口,
/// 成功则记录打开次数并进入终端页,失败则提示错误信息。
Future<void> connectDevice(BuildContext context, Device device) async {
  // 桌面端会话类型兜底拦截(列表 UI 已禁用入口,此处防遗漏)。
  if (!device.isSupportedOnMobile) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('移动端暂不支持 ${device.type.displayName} 类型连接')),
    );
    return;
  }
  final sessionManager = context.read<SessionManager>();
  final deviceController = context.read<DeviceController>();

  // 收集缺失的 SSH 登录凭据(用户取消则中止连接)。
  var effectiveDevice = device;
  if (device.type == ConnectionType.ssh) {
    final collected = await _collectSshCredentials(context, device);
    if (collected == null || !context.mounted) {
      return;
    }
    effectiveDevice = collected;
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConnectingDialog(
      deviceName: effectiveDevice.name,
      host: effectiveDevice.host,
      port: effectiveDevice.port,
    ),
  );

  try {
    final session = await sessionManager
        .connect(effectiveDevice)
        .timeout(AppConstants.connectionTimeout + const Duration(seconds: 30));
    await deviceController.recordOpened(
      effectiveDevice.name,
      folder: effectiveDevice.folder,
    );
    if (!context.mounted) {
      return;
    }
    navigator.pop();
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => TerminalScreen(session: session),
      ),
    );
  } on Object catch (error) {
    if (!context.mounted) {
      return;
    }
    navigator.pop();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('连接失败'),
        content: Text('${effectiveDevice.name} 连接失败:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// SSH 凭据收集结果。
///
/// 返回 null 表示用户取消;否则返回本次连接使用的设备副本,
/// 勾选记住时已同步写入数据库。
///
/// 私钥认证:密钥在首次生成后已通过公钥分发到服务器(ssh-copy),
/// 连接只需账户,不需要也不应要求密码;密码认证:凭据缺失时
/// 弹窗收集并支持记住。
Future<Device?> _collectSshCredentials(
  BuildContext context,
  Device device,
) async {
  // 私钥认证:只确保账户存在,绝不要求密码。
  if (device.usesPrivateKey) {
    if (device.username.trim().isNotEmpty) {
      return device;
    }
    final username = await _askUsernameOnly(context, device);
    if (username == null || !context.mounted) {
      return null;
    }
    // 账户不属于敏感信息,缺失时输入后总是保存。
    await context.read<DeviceController>().updateDevice(
      device.copyWith(username: username),
    );
    return device.copyWith(username: username);
  }

  final hasUsername = device.username.trim().isNotEmpty;
  final hasPassword = device.password.isNotEmpty;

  // 凭据齐全,直接连接。
  if (hasUsername && hasPassword) {
    return device;
  }

  // 已保存账户但未保存密码:仅输入密码。
  if (hasUsername && !hasPassword) {
    final password = await _askPasswordOnly(context);
    if (password == null || !context.mounted) {
      return null;
    }
    if (password.remember) {
      await context.read<DeviceController>().updateDevice(
        device.copyWith(password: password.value),
      );
    }
    return device.copyWith(password: password.value);
  }

  // 未设置账户(不论密码是否存在):输入账户与密码。
  final result = await _askUsernameAndPassword(context, device);
  if (result == null || !context.mounted) {
    return null;
  }
  if (result.remember) {
    await context.read<DeviceController>().updateDevice(
      device.copyWith(username: result.username, password: result.password),
    );
    return device.copyWith(
      username: result.username,
      password: result.password,
    );
  }
  return device.copyWith(username: result.username, password: result.password);
}

/// 私钥认证设备缺失账户时,仅输入账户的对话框(不需要密码)。
Future<String?> _askUsernameOnly(BuildContext context, Device device) {
  final controller = TextEditingController(text: device.username);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('请输入账户'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '账户'),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('连接'),
        ),
      ],
    ),
  );
}

/// 仅输入密码的对话框(已保存账户),带"记住密码"勾选框。
Future<({String value, bool remember})?> _askPasswordOnly(
  BuildContext context,
) async {
  final controller = TextEditingController();
  var rememberState = false;
  final result = await showDialog<({String value, bool remember})?>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('请输入密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: '密码'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('记住密码', style: TextStyle(fontSize: 13)),
              value: rememberState,
              onChanged: (value) {
                setDialogState(() => rememberState = value ?? false);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop((value: controller.text, remember: rememberState)),
            child: const Text('连接'),
          ),
        ],
      ),
    ),
  );
  return result;
}

/// 账户与密码输入对话框(未设置账户),带"记住账户和密码"勾选框。
Future<({String username, String password, bool remember})?>
_askUsernameAndPassword(BuildContext context, Device device) async {
  final usernameController = TextEditingController(text: device.username);
  final passwordController = TextEditingController();
  var remember = false;
  return showDialog<({String username, String password, bool remember})?>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('请输入账户与密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '账户'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('记住账户和密码', style: TextStyle(fontSize: 13)),
              value: remember,
              onChanged: (value) {
                setDialogState(() => remember = value ?? false);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop((
              username: usernameController.text.trim(),
              password: passwordController.text,
              remember: remember,
            )),
            child: const Text('连接'),
          ),
        ],
      ),
    ),
  );
}
