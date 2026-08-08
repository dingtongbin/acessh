// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// SSH 认证方式。
enum AuthMethod {
  /// 用户名 + 密码认证。
  password,

  /// 私钥认证(密钥文件)。
  privateKey;

  /// 数据库存储值。
  String get storageValue => name;

  /// 从数据库值解析,未知值回退为 [AuthMethod.password]。
  static AuthMethod fromStorage(String value) {
    return AuthMethod.values.firstWhere(
      (method) => method.storageValue == value,
      orElse: () => AuthMethod.password,
    );
  }

  /// 界面展示名。
  String get displayName => switch (this) {
    AuthMethod.password => '密码',
    AuthMethod.privateKey => '私钥',
  };
}
