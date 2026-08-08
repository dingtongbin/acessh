// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 终端主题选项。
enum TerminalThemeMode {
  /// 深色主题。
  dark,

  /// 浅色主题。
  light,
}

/// 应用主题模式。
enum AppThemeMode {
  /// 跟随系统。
  system,

  /// 强制浅色。
  light,

  /// 强制深色。
  dark,
}

/// 退出会话时默认采取的动作。
enum ExitAction {
  /// 关闭连接并退出。
  close,

  /// 挂起到后台(连接保持)。
  background;

  /// 界面展示名。
  String get displayName => switch (this) {
    ExitAction.close => '关闭连接退出',
    ExitAction.background => '后台挂起退出',
  };
}

/// 应用设置:主题、终端外观、退出偏好与应用锁开关,持久化到 shared_preferences。
class AppSettings extends ChangeNotifier {
  AppSettings._();

  /// 全局唯一实例。
  static final AppSettings instance = AppSettings._();

  static const _keyThemeMode = 'app_theme_mode';
  static const _keyThemeColor = 'app_theme_color';
  static const _keyTerminalTheme = 'terminal_theme';
  static const _keyFontSize = 'terminal_font_size';
  static const _keyShowQuickBar = 'terminal_show_quick_bar';
  static const _keyRememberExitAction = 'exit_remember_action';
  static const _keyExitAction = 'exit_action';
  static const _keyTextColor = 'terminal_text_color';
  static const _keyFontFamily = 'terminal_font_family';
  static const _keyCopyOnSelect = 'terminal_copy_on_select';
  static const _keyCursorBlink = 'terminal_cursor_blink';
  static const _keyBackgroundImage = 'terminal_background_image';
  static const _keyOpacity = 'terminal_opacity';
  static const _keyAppLockEnabled = 'app_lock_enabled';
  static const _keyAppLockMode = 'app_lock_mode';
  static const _keyAppLockPin = 'app_lock_pin';
  static const _keyAppLockPattern = 'app_lock_pattern';
  static const _keyLicenseAccepted = 'license_accepted';

  SharedPreferences? _prefs;

  AppThemeMode _themeMode = AppThemeMode.system;
  Color _themeColor = const Color(0xFF37474F);
  TerminalThemeMode _terminalTheme = TerminalThemeMode.dark;
  double _fontSize = 14;
  bool _showQuickBar = true;
  bool _rememberExitAction = false;
  ExitAction _exitAction = ExitAction.background;
  Color _textColor = const Color(0xFFCCCCCC);
  String _fontFamily = 'monospace';
  bool _copyOnSelect = true;
  bool _cursorBlink = true;
  String _backgroundImagePath = '';
  double _opacity = 1;
  bool _appLockEnabled = false;
  String _appLockMode = 'none';
  String _appLockPin = '';
  String _appLockPattern = '';
  bool _licenseAccepted = false;

  /// 应用主题模式。
  AppThemeMode get themeMode => _themeMode;

  /// 应用主题色(seed 色)。
  Color get themeColor => _themeColor;

  /// 终端主题。
  TerminalThemeMode get terminalTheme => _terminalTheme;

  /// 终端字体大小。
  double get fontSize => _fontSize;

  /// 是否显示快捷栏。
  bool get showQuickBar => _showQuickBar;

  /// 是否记住退出动作。
  bool get rememberExitAction => _rememberExitAction;

  /// 记住的退出动作。
  ExitAction get exitAction => _exitAction;

  /// 终端纯文本字体颜色。
  Color get textColor => _textColor;

  /// 终端字体。
  String get fontFamily => _fontFamily;

  /// 选中后自动复制。
  bool get copyOnSelect => _copyOnSelect;

  /// 光标闪烁。
  bool get cursorBlink => _cursorBlink;

  /// 终端背景图片绝对路径(空串表示无)。
  String get backgroundImagePath => _backgroundImagePath;

  /// 终端字体与背景透明度(0.1-1.0,1 为完全不透明)。
  double get opacity => _opacity;

  /// 应用锁是否开启。
  bool get appLockEnabled => _appLockEnabled;

  /// 应用锁模式(none/pin/pattern)。
  String get appLockMode => _appLockMode;

  /// 应用锁密码。
  String get appLockPin => _appLockPin;

  /// 应用锁图案(以序号列表编码)。
  String get appLockPattern => _appLockPattern;

  /// 是否已配置应用锁凭据。
  bool get hasAppLockCredential =>
      (_appLockMode == 'pin' && _appLockPin.isNotEmpty) ||
      (_appLockMode == 'pattern' && _appLockPattern.isNotEmpty);

  /// 是否已同意用户许可。
  bool get licenseAccepted => _licenseAccepted;

  /// 从本地存储加载设置。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _themeMode = switch (prefs.getString(_keyThemeMode)) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
    _themeColor = Color(
      prefs.getInt(_keyThemeColor) ?? const Color(0xFF37474F).toARGB32(),
    );
    _terminalTheme = prefs.getString(_keyTerminalTheme) == 'light'
        ? TerminalThemeMode.light
        : TerminalThemeMode.dark;
    _fontSize = prefs.getDouble(_keyFontSize) ?? 14;
    _showQuickBar = prefs.getBool(_keyShowQuickBar) ?? true;
    _rememberExitAction = prefs.getBool(_keyRememberExitAction) ?? false;
    _exitAction = prefs.getString(_keyExitAction) == 'close'
        ? ExitAction.close
        : ExitAction.background;
    _textColor = Color(
      prefs.getInt(_keyTextColor) ?? const Color(0xFFCCCCCC).toARGB32(),
    );
    _fontFamily = prefs.getString(_keyFontFamily) ?? 'monospace';
    _copyOnSelect = prefs.getBool(_keyCopyOnSelect) ?? true;
    _cursorBlink = prefs.getBool(_keyCursorBlink) ?? true;
    _backgroundImagePath = prefs.getString(_keyBackgroundImage) ?? '';
    _opacity = (prefs.getDouble(_keyOpacity) ?? 1).clamp(0.1, 1);
    _appLockEnabled = prefs.getBool(_keyAppLockEnabled) ?? false;
    _appLockMode = prefs.getString(_keyAppLockMode) ?? 'none';
    _appLockPin = prefs.getString(_keyAppLockPin) ?? '';
    _appLockPattern = prefs.getString(_keyAppLockPattern) ?? '';
    _licenseAccepted = prefs.getBool(_keyLicenseAccepted) ?? false;
    notifyListeners();
  }

  /// 设置应用主题模式。
  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString(_keyThemeMode, switch (mode) {
      AppThemeMode.system => 'system',
      AppThemeMode.light => 'light',
      AppThemeMode.dark => 'dark',
    });
    notifyListeners();
  }

  /// 设置应用主题色并持久化。
  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    await _prefs?.setInt(_keyThemeColor, color.toARGB32());
    notifyListeners();
  }

  /// 设置终端主题并持久化。
  Future<void> setTerminalTheme(TerminalThemeMode mode) async {
    _terminalTheme = mode;
    await _prefs?.setString(
      _keyTerminalTheme,
      mode == TerminalThemeMode.light ? 'light' : 'dark',
    );
    notifyListeners();
  }

  /// 设置字体大小并持久化。
  Future<void> setFontSize(double size) async {
    _fontSize = size;
    await _prefs?.setDouble(_keyFontSize, size);
    notifyListeners();
  }

  /// 设置快捷栏显隐并持久化。
  Future<void> setShowQuickBar(bool show) async {
    _showQuickBar = show;
    await _prefs?.setBool(_keyShowQuickBar, show);
    notifyListeners();
  }

  /// 设置退出动作记忆偏好并持久化。
  Future<void> setExitPreference({
    required bool remember,
    required ExitAction action,
  }) async {
    _rememberExitAction = remember;
    _exitAction = action;
    await _prefs?.setBool(_keyRememberExitAction, remember);
    await _prefs?.setString(
      _keyExitAction,
      action == ExitAction.close ? 'close' : 'background',
    );
    notifyListeners();
  }

  /// 设置终端纯文本字体颜色并持久化。
  Future<void> setTextColor(Color color) async {
    _textColor = color;
    await _prefs?.setInt(_keyTextColor, color.toARGB32());
    notifyListeners();
  }

  /// 设置终端字体并持久化。
  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    await _prefs?.setString(_keyFontFamily, family);
    notifyListeners();
  }

  /// 设置选中复制开关并持久化。
  Future<void> setCopyOnSelect(bool enabled) async {
    _copyOnSelect = enabled;
    await _prefs?.setBool(_keyCopyOnSelect, enabled);
    notifyListeners();
  }

  /// 设置光标闪烁开关并持久化。
  Future<void> setCursorBlink(bool enabled) async {
    _cursorBlink = enabled;
    await _prefs?.setBool(_keyCursorBlink, enabled);
    notifyListeners();
  }

  /// 设置终端背景图片路径并持久化(空串清除)。
  Future<void> setBackgroundImagePath(String path) async {
    _backgroundImagePath = path;
    await _prefs?.setString(_keyBackgroundImage, path);
    notifyListeners();
  }

  /// 设置终端透明度并持久化(0.1-1.0)。
  Future<void> setOpacity(double value) async {
    _opacity = value.clamp(0.1, 1);
    await _prefs?.setDouble(_keyOpacity, _opacity);
    notifyListeners();
  }

  /// 设置应用锁状态并持久化。
  Future<void> setAppLock({
    required bool enabled,
    required String mode,
    String pin = '',
    String pattern = '',
  }) async {
    _appLockEnabled = enabled;
    _appLockMode = enabled ? mode : 'none';
    _appLockPin = pin;
    _appLockPattern = pattern;
    await _prefs?.setBool(_keyAppLockEnabled, enabled);
    await _prefs?.setString(_keyAppLockMode, _appLockMode);
    await _prefs?.setString(_keyAppLockPin, pin);
    await _prefs?.setString(_keyAppLockPattern, pattern);
    notifyListeners();
  }

  /// 关闭应用锁。
  Future<void> disableAppLock() async {
    await setAppLock(enabled: false, mode: 'none');
  }

  /// 记录用户已同意许可。
  Future<void> setLicenseAccepted() async {
    _licenseAccepted = true;
    await _prefs?.setBool(_keyLicenseAccepted, true);
    notifyListeners();
  }
}
