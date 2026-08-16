// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// 设备支持的远程连接类型。
///
/// 除移动端可连接的 [ssh]/[telnet]/[serial] 外,还识别桌面端 AceShell
/// 会话文件中的其他类型(sftp/vnc/rdp/x11),便于展示与编辑;
/// 未知类型统一归为 [unsupported]。
enum ConnectionType {
  /// SSH 远程登录(22 端口)。
  ssh,

  /// Telnet 远程登录(23 端口)。
  telnet,

  /// 本地串口连接。
  serial,

  /// SFTP 文件传输(桌面端类型,移动端暂不支持连接)。
  sftp,

  /// VNC 远程桌面(桌面端类型,移动端暂不支持连接)。
  vnc,

  /// RDP 远程桌面(桌面端类型,移动端暂不支持连接)。
  rdp,

  /// X11 转发(桌面端类型,移动端暂不支持连接)。
  x11,

  /// 未知会话类型(TOML 中识别到但无法归类的类型)。
  unsupported;

  /// 存储值(TOML/JSON 中的 type 字段)。
  String get storageValue => name;

  /// 从存储值解析,未知值归为 [ConnectionType.unsupported]
  /// (不回退 ssh,保证未知类型能被识别与展示)。
  static ConnectionType fromStorage(String value) {
    return ConnectionType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => ConnectionType.unsupported,
    );
  }

  /// 移动端是否支持连接(仅 SSH/Telnet/串口)。
  bool get isSupportedOnMobile {
    return this == ConnectionType.ssh ||
        this == ConnectionType.telnet ||
        this == ConnectionType.serial;
  }

  /// 界面展示名。
  String get displayName => switch (this) {
    ConnectionType.ssh => 'SSH',
    ConnectionType.telnet => 'Telnet',
    ConnectionType.serial => '串口',
    ConnectionType.sftp => 'SFTP',
    ConnectionType.vnc => 'VNC',
    ConnectionType.rdp => 'RDP',
    ConnectionType.x11 => 'X11',
    ConnectionType.unsupported => '未知',
  };
}
