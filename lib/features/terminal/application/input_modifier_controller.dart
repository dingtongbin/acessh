// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/foundation.dart';

/// 输入修饰键锁定状态(全局单例)。
///
/// 快捷栏点击 Ctrl/Alt 后锁定修饰,下一个输入(虚拟键或系统键盘)自动组合,
/// 例如 Ctrl 锁定后输入 c 会发送 Ctrl+C;发送完成后自动解锁。
/// Fn 模式用于切换虚拟键为 F1-F12 布局。
class InputModifierController extends ChangeNotifier {
  InputModifierController._();

  /// 全局唯一实例。
  static final InputModifierController instance = InputModifierController._();

  /// Ctrl 是否锁定。
  bool _ctrlLocked = false;

  /// Alt 是否锁定。
  bool _altLocked = false;

  /// 是否处于 Fn 模式(F1-F12 虚拟键布局)。
  bool _fnMode = false;

  /// Ctrl 锁定状态。
  bool get ctrlLocked => _ctrlLocked;

  /// Alt 锁定状态。
  bool get altLocked => _altLocked;

  /// Fn 模式状态。
  bool get fnMode => _fnMode;

  /// 设置 Ctrl 锁定状态。
  void setCtrlLocked(bool locked) {
    if (_ctrlLocked == locked) {
      return;
    }
    _ctrlLocked = locked;
    notifyListeners();
  }

  /// 设置 Alt 锁定状态。
  void setAltLocked(bool locked) {
    if (_altLocked == locked) {
      return;
    }
    _altLocked = locked;
    notifyListeners();
  }

  /// 设置 Fn 模式。
  void setFnMode(bool enabled) {
    if (_fnMode == enabled) {
      return;
    }
    _fnMode = enabled;
    notifyListeners();
  }

  /// 解锁全部修饰键(不重置 Fn 模式)。
  void reset() {
    if (!_ctrlLocked && !_altLocked) {
      return;
    }
    _ctrlLocked = false;
    _altLocked = false;
    notifyListeners();
  }
}
