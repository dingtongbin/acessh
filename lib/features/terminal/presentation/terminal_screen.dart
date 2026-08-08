// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kterm/kterm.dart';

import '../../../core/logging/app_logger.dart';
import '../../connection/application/session_manager.dart';
import '../../connection/application/terminal_session.dart';
import '../../device/domain/connection_type.dart';
import '../../settings/application/app_settings.dart';
import '../../settings/presentation/terminal_settings_screen.dart';
import '../application/terminal_theme_builder.dart';
import 'background_sessions_sheet.dart';
import 'exit_dialog.dart';
import 'quick_input_bar.dart';
import 'script_execute_sheet.dart';

/// 终端页:顶部工具栏(后台连接/脚本执行/终端设置)、kterm 终端区与底部快捷栏。
///
/// 交互:单击聚焦;双击文本选词(kterm 内置)、双击空白行切换系统键盘;
/// 三击文本行选中整行;连接断开时可重连;支持光标闪烁与选中复制。
class TerminalScreen extends StatefulWidget {
  /// 创建终端页并绑定指定会话。
  const TerminalScreen({required this.session, super.key});

  /// 要展示的会话。
  final TerminalSession session;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final FocusNode _focusNode = FocusNode();
  final TerminalController _terminalController = TerminalController();
  final List<DateTime> _tapTimes = [];
  Timer? _blinkTimer;
  bool _cursorVisible = true;
  bool _reconnecting = false;

  /// 是否允许系统键盘弹出(首次进入/按钮拉起时置 true,
  /// 收起后置 false 以阻止 kterm 点击自动聚焦)。
  final ValueNotifier<bool> _keyboardEnabled = ValueNotifier<bool>(true);

  TerminalSession get session => widget.session;

  /// 多击判定间隔。
  static const Duration _tapInterval = Duration(milliseconds: 300);

  /// 光标闪烁周期。
  static const Duration _blinkPeriod = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _terminalController.addListener(_handleSelectionChanged);
    _keyboardEnabled.addListener(_syncKeyboardFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupBlink(context.read<AppSettings>().cursorBlink);
  }

  @override
  void dispose() {
    _keyboardEnabled.removeListener(_syncKeyboardFocus);
    _keyboardEnabled.dispose();
    _blinkTimer?.cancel();
    _terminalController.removeListener(_handleSelectionChanged);
    _terminalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 键盘允许状态与焦点可请求状态同步:
  /// 不允许时 kterm 的点击自动聚焦会被拒绝,输入法不会弹出。
  void _syncKeyboardFocus() {
    _focusNode.canRequestFocus = _keyboardEnabled.value;
  }

  /// 切换系统键盘显隐(快捷栏按钮与空白处双击共用)。
  void _toggleKeyboard() {
    if (_keyboardEnabled.value) {
      _keyboardEnabled.value = false;
      _focusNode.unfocus();
    } else {
      _keyboardEnabled.value = true;
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _confirmExit(context);
      },
      child: Scaffold(
        // 禁用 body 随键盘压缩,终端区域保持原尺寸,弹出输入法不抖动。
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: ListenableBuilder(
            listenable: session,
            builder: (context, _) => GestureDetector(
              onLongPress: () => _showSessionInfo(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    _statusText(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ListenableBuilder(
              listenable: session,
              builder: (context, _) {
                if (session.state != TerminalSessionState.disconnected) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: _reconnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: '重新连接',
                  onPressed: _reconnecting ? null : _reconnect,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.layers_outlined),
              tooltip: '后台连接',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (context) => const BackgroundSessionsSheet(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.terminal_outlined),
              tooltip: '脚本执行',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => ScriptExecuteSheet(session: session),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '终端设置',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const TerminalSettingsScreen(),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                decoration: _terminalBackground(settings),
                child: TerminalView(
                  session.terminal,
                  controller: _terminalController,
                  focusNode: _focusNode,
                  autofocus: true,
                  deleteDetection: true,
                  backgroundOpacity: settings.opacity,
                  theme: _terminalTheme(settings),
                  textStyle: TerminalStyle(
                    fontSize: settings.fontSize,
                    fontFamily: settings.fontFamily,
                  ),
                  onTapUp: (details, cell) => _handleTap(cell),
                ),
              ),
            ),
            if (settings.showQuickBar)
              QuickInputBar(
                terminal: session.terminal,
                focusNode: _focusNode,
                keyboardEnabled: _keyboardEnabled,
                onKeyboardToggle: _toggleKeyboard,
              ),
            // 键盘弹出时快捷栏整体上移(键盘遮挡该区域),终端画面保持不动。
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  /// 依据设置启用/停用光标闪烁(kterm 无内置闪烁,用可见性定时切换模拟)。
  void _setupBlink(bool enabled) {
    _blinkTimer?.cancel();
    _cursorVisible = true;
    session.terminal.setCursorVisibleMode(true);
    if (enabled) {
      _blinkTimer = Timer.periodic(_blinkPeriod, (_) {
        _cursorVisible = !_cursorVisible;
        session.terminal.setCursorVisibleMode(_cursorVisible);
      });
    }
  }

  /// 选中变化:开启选中复制时自动写入剪贴板。
  void _handleSelectionChanged() {
    final selection = _terminalController.selection;
    final settings = AppSettings.instance;
    if (selection == null || !settings.copyOnSelect) {
      return;
    }
    final text = session.terminal.buffer.getText(selection);
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
    }
  }

  /// 处理终端区点击:单击不弹输入法(kterm 会自动请求聚焦,
  /// 通过键盘允许状态拒绝);双击文本选词(kterm 内置)且空白行切换键盘;
  /// 三击文本行选中整行,空白行不触发三击。
  void _handleTap(CellOffset cell) {
    final now = DateTime.now();
    _tapTimes
      ..removeWhere((time) => now.difference(time) > _tapInterval)
      ..add(now);

    if (_tapTimes.length >= 3) {
      _tapTimes.clear();
      _selectLineIfHasText(cell);
      return;
    }
    if (_tapTimes.length == 2) {
      if (!_lineHasText(cell.y)) {
        // 空白行双击:切换系统键盘。
        _toggleKeyboard();
      }
      // 文本行双击由 kterm 内置 selectWord 处理。
      return;
    }
    // 单击:不弹起输入法。
    // 键盘已收起时,禁止 kterm 的点击自动聚焦。
    if (!_focusNode.hasFocus && _keyboardEnabled.value) {
      _keyboardEnabled.value = false;
    }
  }

  /// 该行是否包含文本。
  bool _lineHasText(int y) {
    final lines = session.terminal.lines;
    if (y < 0 || y >= lines.length) {
      return false;
    }
    return lines[y].getText().trim().isNotEmpty;
  }

  /// 三击:若点击位置所在行有文本则选中整行。
  void _selectLineIfHasText(CellOffset cell) {
    if (!_lineHasText(cell.y)) {
      return;
    }
    final lines = session.terminal.lines;
    final line = lines[cell.y];
    _terminalController.setSelection(
      CellAnchor(0, owner: line),
      CellAnchor(line.length - 1, owner: line),
      mode: SelectionMode.line,
    );
  }

  /// 重新连接当前会话。
  Future<void> _reconnect() async {
    if (_reconnecting) {
      return;
    }
    setState(() => _reconnecting = true);
    try {
      await session.reconnect();
    } on Object catch (error, stackTrace) {
      AppLogger.e('重新连接失败', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('重连失败:$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _reconnecting = false);
      }
    }
  }

  /// 会话状态文本。
  String _statusText() {
    return switch (session.state) {
      TerminalSessionState.connecting => '连接中',
      TerminalSessionState.connected => '已连接',
      TerminalSessionState.background => '后台挂起',
      TerminalSessionState.disconnected => '已断开',
    };
  }

  /// 长按标题展示会话完整信息。
  void _showSessionInfo(BuildContext context) {
    final device = session.device;
    final details = [
      '会话名:${session.label}',
      '设备名:${device.name}',
      '类型:${device.type.displayName}',
      if (device.type == ConnectionType.serial)
        '串口:${device.host} · ${device.baudRate} baud'
      else
        '主机:${device.host}:${device.port}',
      if (device.username.isNotEmpty) '用户名:${device.username}',
      if (device.note.isNotEmpty) '备注:${device.note}',
      '状态:${_statusText()}',
    ].join('\n');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会话信息'),
        content: SelectableText(details),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 终端背景:有背景图片时图片垫底,无图片时使用主题背景色。
  BoxDecoration _terminalBackground(AppSettings settings) {
    final dark = settings.terminalTheme == TerminalThemeMode.dark;
    final baseColor = dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final imagePath = settings.backgroundImagePath;
    if (imagePath.isEmpty) {
      return BoxDecoration(
        color: baseColor.withValues(alpha: settings.opacity),
      );
    }
    return BoxDecoration(
      color: baseColor.withValues(alpha: settings.opacity),
      image: DecorationImage(
        image: FileImage(File(imagePath)),
        fit: BoxFit.cover,
      ),
    );
  }

  /// 依据设置构建终端主题(深=黑底白字,浅=白底黑字,前景可自定义)。
  TerminalTheme _terminalTheme(AppSettings settings) {
    return TerminalThemeBuilder.build(
      dark: settings.terminalTheme == TerminalThemeMode.dark,
      foreground: settings.textColor,
      opacity: settings.opacity,
    );
  }

  /// 弹出退出确认对话框并按选择执行。
  Future<void> _confirmExit(BuildContext context) async {
    final settings = context.read<AppSettings>();
    if (settings.rememberExitAction) {
      await _performExit(settings.exitAction);
      return;
    }
    final result = await showDialog<ExitDialogResult>(
      context: context,
      builder: (context) => ExitDialog(
        initialRemember: settings.rememberExitAction,
        initialAction: settings.exitAction,
      ),
    );
    if (result == null) {
      return;
    }
    await settings.setExitPreference(
      remember: result.remember,
      action: result.action,
    );
    if (!mounted) {
      return;
    }
    await _performExit(result.action);
  }

  /// 执行退出动作:关闭连接或后台挂起,随后返回上一页。
  Future<void> _performExit(ExitAction action) async {
    final sessionManager = context.read<SessionManager>();
    try {
      if (action == ExitAction.close) {
        await sessionManager.closeSession(session);
      } else {
        sessionManager.backgroundCurrent();
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('退出会话失败', error, stackTrace);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
