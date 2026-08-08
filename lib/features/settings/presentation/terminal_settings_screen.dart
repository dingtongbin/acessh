// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/paths/app_paths.dart';
import '../application/app_settings.dart';
import '../application/font_probe_service.dart';

/// 终端设置页:主题、字体大小、纯文本颜色、字体、光标闪烁与选中复制等。
class TerminalSettingsScreen extends StatefulWidget {
  /// 创建终端设置页。
  const TerminalSettingsScreen({super.key});

  @override
  State<TerminalSettingsScreen> createState() => _TerminalSettingsScreenState();
}

class _TerminalSettingsScreenState extends State<TerminalSettingsScreen> {
  /// 当前已探测字体(下拉触发时懒加载)。
  List<String>? _probedFonts;

  /// 纯文本颜色选项。
  static const List<Color> _colorOptions = [
    Color(0xFFCCCCCC),
    Color(0xFFFFFFFF),
    Color(0xFF33FF33),
    Color(0xFF00FF00),
    Color(0xFF00BFFF),
    Color(0xFFFFAA00),
    Color(0xFFFF6EC7),
    Color(0xFF00FFAA),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('终端设置')),
      body: ListView(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('终端主题'),
            subtitle: SegmentedButton<TerminalThemeMode>(
              segments: const [
                ButtonSegment(
                  value: TerminalThemeMode.dark,
                  label: Text('深色'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: TerminalThemeMode.light,
                  label: Text('浅色'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
              ],
              selected: {settings.terminalTheme},
              onSelectionChanged: (selection) {
                settings.setTerminalTheme(selection.first);
              },
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('字体大小'),
            subtitle: Slider(
              value: settings.fontSize,
              min: 10,
              max: 24,
              divisions: 14,
              label: '${settings.fontSize.round()}',
              onChanged: (value) => settings.setFontSize(value),
            ),
            trailing: Text('${settings.fontSize.round()}'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('纯文本颜色', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final color in _colorOptions)
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: color, radius: 8),
                    label: const Text(''),
                    selected: settings.textColor.toARGB32() == color.toARGB32(),
                    onSelected: (_) => settings.setTextColor(color),
                  ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('终端字体'),
            subtitle: DropdownButtonFormField<String>(
              initialValue: settings.fontFamily,
              decoration: const InputDecoration(
                labelText: '选择字体',
                prefixIcon: Icon(Icons.font_download_outlined),
              ),
              items: [
                for (final family in (_probedFonts ?? [settings.fontFamily]))
                  DropdownMenuItem(value: family, child: Text(family)),
              ],
              // 下拉展开时自动探测系统字体。
              onTap: _probeFonts,
              onChanged: (value) {
                if (value != null) {
                  settings.setFontFamily(value);
                }
              },
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('光标闪烁'),
            subtitle: const Text('光标按 500ms 周期闪烁'),
            value: settings.cursorBlink,
            onChanged: (value) => settings.setCursorBlink(value),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('选中复制'),
            subtitle: const Text('选中文本后自动复制到剪贴板'),
            value: settings.copyOnSelect,
            onChanged: (value) => settings.setCopyOnSelect(value),
          ),
          const Divider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('终端透明度'),
            subtitle: const Text('控制字体与终端背景的透明度'),
            trailing: Text('${(settings.opacity * 100).round()}%'),
            onTap: () {},
          ),
          Slider(
            value: settings.opacity,
            min: 0.1,
            max: 1,
            divisions: 9,
            label: '${(settings.opacity * 100).round()}%',
            onChanged: (value) => settings.setOpacity(value),
          ),
          const Divider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('终端背景图片'),
            subtitle: const Text('图片垫在终端底下,配合透明度使用'),
            trailing: settings.backgroundImagePath.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: '清除背景图片',
                    onPressed: () => settings.setBackgroundImagePath(''),
                  ),
            onTap: _pickBackgroundImage,
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('显示快捷栏'),
            value: settings.showQuickBar,
            onChanged: (value) => settings.setShowQuickBar(value),
          ),
        ],
      ),
    );
  }

  /// 选择终端背景图片并复制到应用目录。
  Future<void> _pickBackgroundImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        dialogTitle: '选择终端背景图片',
      );
      final path = result?.files.single.path;
      if (path == null) {
        return;
      }
      final source = File(path);
      final dir = await AppPaths.backgroundsDirectory();
      final name =
          '${DateTime.now().millisecondsSinceEpoch}'
          '${_extensionOf(path)}';
      final target = File('${dir.path}${Platform.pathSeparator}$name');
      await source.copy(target.path);
      if (mounted) {
        await context.read<AppSettings>().setBackgroundImagePath(target.path);
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('选择背景图片失败', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择背景图片失败:$error')));
      }
    }
  }

  /// 取文件扩展名。
  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) {
      return '';
    }
    return path.substring(dot);
  }

  /// 探测系统字体并刷新下拉列表。
  Future<void> _probeFonts() async {
    if (_probedFonts != null) {
      return;
    }
    final fonts = await FontProbeService.probeAvailableFonts();
    if (mounted) {
      setState(() => _probedFonts = fonts);
    }
  }
}
