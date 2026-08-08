// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../../connection/application/serial_session.dart';

/// 串口设备选择控件:自动扫描可用串口,仅能从中选择,无法手动输入。
class SerialPortField extends StatefulWidget {
  /// 创建串口选择控件。
  const SerialPortField({required this.controller, this.validator, super.key});

  /// 串口路径文本控制器(保存时读取)。
  final TextEditingController controller;

  /// 表单校验器。
  final FormFieldValidator<String>? validator;

  @override
  State<SerialPortField> createState() => _SerialPortFieldState();
}

class _SerialPortFieldState extends State<SerialPortField> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    final initial = widget.controller.text.trim();
    if (initial.isNotEmpty) {
      _selected = initial;
    }
  }

  /// 扫描可用串口列表。
  List<String> _scanPorts() {
    return SerialSession.availablePorts();
  }

  /// 刷新串口列表并提示结果。
  void _refresh() {
    final ports = _scanPorts();
    if (!mounted) {
      return;
    }
    if (ports.isEmpty) {
      setState(() {
        _selected = null;
        widget.controller.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未发现可用串口')));
      return;
    }
    setState(() {
      _selected = ports.first;
      widget.controller.text = ports.first;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('可用串口:${ports.join(', ')}')));
  }

  @override
  Widget build(BuildContext context) {
    final ports = _scanPorts();
    if (_selected != null && !ports.contains(_selected)) {
      // 已选串口不在当前列表中,保持选择但提示可刷新。
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _selected,
            decoration: const InputDecoration(
              labelText: '串口设备(自动扫描)',
              prefixIcon: Icon(Icons.usb),
            ),
            hint: ports.isEmpty ? const Text('未发现串口,点击刷新') : null,
            items: [
              for (final port in ports)
                DropdownMenuItem(value: port, child: Text(port)),
            ],
            onChanged: (value) {
              setState(() => _selected = value);
              if (value != null) {
                widget.controller.text = value;
              }
            },
            validator:
                widget.validator ??
                (value) => (value == null || value.isEmpty) ? '请选择串口' : null,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: IconButton.filledTonal(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '刷新串口列表',
            onPressed: _refresh,
          ),
        ),
      ],
    );
  }
}
