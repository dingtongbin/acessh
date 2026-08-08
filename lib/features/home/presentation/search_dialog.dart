// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../device/application/device_controller.dart';

/// 模糊搜索对话框:输入关键字即时过滤设备列表(会话名/主机/用户名)。
class SearchDialog extends StatefulWidget {
  /// 创建搜索对话框。
  const SearchDialog({super.key});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<DeviceController>().keyword,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceController>();
    return AlertDialog(
      title: const Text('搜索设备'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '输入会话名、主机或用户名',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: controller.setKeyword,
      ),
      actions: [
        TextButton(
          onPressed: () {
            _controller.clear();
            controller.setKeyword('');
          },
          child: const Text('清除'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
