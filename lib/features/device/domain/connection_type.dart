// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// 设备支持的远程连接类型。
enum ConnectionType {
  /// SSH 远程登录(22 端口)。
  ssh,

  /// Telnet 远程登录(23 端口)。
  telnet,

  /// 本地串口连接。
  serial;

  /// 数据库存储值。
  String get storageValue => name;

  /// 从数据库值解析,未知值回退为 [ConnectionType.ssh]。
  static ConnectionType fromStorage(String value) {
    return ConnectionType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => ConnectionType.ssh,
    );
  }

  /// 界面展示名。
  String get displayName => switch (this) {
    ConnectionType.ssh => 'SSH',
    ConnectionType.telnet => 'Telnet',
    ConnectionType.serial => '串口',
  };
}
