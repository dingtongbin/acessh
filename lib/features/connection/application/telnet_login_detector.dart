// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// Telnet 自动登录检测器:扫描服务器输出,识别登录提示并自动回填凭据。
///
/// 用户名/密码均可为空(设备未配置时跳过对应的自动输入):
/// - 检测到 "login" 提示且配置了用户名 → 自动输入用户名;
/// - 检测到 "password" 提示且配置了密码 → 自动输入密码。
/// 状态机保证用户名与密码各只发送一次,完成后进入结束态不再响应提示。
class TelnetLoginDetector {
  /// 创建检测器。
  TelnetLoginDetector({required this.username, required this.password});

  /// 自动登录用户名(可为空,为空时跳过用户名输入)。
  final String username;

  /// 自动登录密码(可为空,为空时跳过密码输入)。
  final String password;

  /// 是否已发送用户名。
  bool _usernameSent = false;

  /// 是否已发送密码。
  bool _passwordSent = false;

  /// 登录流程是否已结束。
  bool get isCompleted =>
      (username.isEmpty || _usernameSent) &&
      (password.isEmpty || _passwordSent);

  /// 处理一段服务器输出,发现登录提示时通过 [onSend] 回填凭据。
  void process(String text, {required void Function(String text) onSend}) {
    if (isCompleted) {
      return;
    }
    final lowered = text.toLowerCase();
    if (username.isNotEmpty &&
        !_usernameSent &&
        _containsLoginPrompt(lowered)) {
      _usernameSent = true;
      onSend('$username\r\n');
    }
    if (password.isNotEmpty &&
        !_passwordSent &&
        _containsPasswordPrompt(lowered)) {
      _passwordSent = true;
      onSend('$password\r\n');
    }
  }

  /// 是否包含用户名提示关键字(如 "login:"、"login " 等)。
  bool _containsLoginPrompt(String lowered) {
    return lowered.contains('login:') ||
        lowered.contains('login ') ||
        lowered.contains('login\r\n');
  }

  /// 是否包含密码提示关键字(如 "password:"、"password " 等)。
  bool _containsPasswordPrompt(String lowered) {
    return lowered.contains('password:') || lowered.contains('password ');
  }

  /// 重置检测器状态(例如重连时)。
  void reset() {
    _usernameSent = false;
    _passwordSent = false;
  }
}
