// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'auth_method.dart';
import 'connection_type.dart';

/// 设备(会话)领域模型,主键为会话名 [name]。
///
/// 会话名同时是数据库主键,因此设备列表中的名称必须唯一。
class Device {
  /// 会话名(数据库主键,唯一)。
  final String name;

  /// 连接类型。
  final ConnectionType type;

  /// 主机地址(串口类型时为串口设备路径)。
  final String host;

  /// 端口(串口类型时忽略)。
  final int port;

  /// 登录用户名。
  final String username;

  /// 登录密码(仅密码认证使用)。
  final String password;

  /// 认证方式(仅 SSH 使用)。
  final AuthMethod authMethod;

  /// OpenSSH 私钥 PEM 内容(仅私钥认证使用)。
  final String privateKey;

  /// 私钥口令(仅加密私钥使用,可为空)。
  final String privateKeyPassphrase;

  /// SSH 主机指纹(OpenSSH 格式 SHA256:xxx,首次连接确认后保存)。
  final String hostKey;

  /// 串口波特率(仅串口类型使用)。
  final int baudRate;

  /// 备注(用途说明)。
  final String note;

  /// 标签(每台设备一个标签,用于筛选)。
  final String tag;

  /// 累计打开次数,用于排序统计。
  final int openCount;

  /// 最近一次成功连接的时间戳(毫秒),未连接过为 null。
  final int? lastConnectedAt;

  /// 创建时间戳(毫秒)。
  final int createdAt;

  /// 最后更新时间戳(毫秒)。
  final int updatedAt;

  /// 创建设备。
  const Device({
    required this.name,
    required this.type,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.authMethod,
    required this.privateKey,
    required this.privateKeyPassphrase,
    required this.hostKey,
    required this.baudRate,
    required this.note,
    required this.tag,
    required this.openCount,
    required this.lastConnectedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 是否使用私钥认证。
  bool get usesPrivateKey => authMethod == AuthMethod.privateKey;

  /// 复制并替换部分字段。
  Device copyWith({
    String? name,
    ConnectionType? type,
    String? host,
    int? port,
    String? username,
    String? password,
    AuthMethod? authMethod,
    String? privateKey,
    String? privateKeyPassphrase,
    String? hostKey,
    int? baudRate,
    String? note,
    String? tag,
    int? openCount,
    int? lastConnectedAt,
    int? createdAt,
    int? updatedAt,
  }) {
    return Device(
      name: name ?? this.name,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      authMethod: authMethod ?? this.authMethod,
      privateKey: privateKey ?? this.privateKey,
      privateKeyPassphrase: privateKeyPassphrase ?? this.privateKeyPassphrase,
      hostKey: hostKey ?? this.hostKey,
      baudRate: baudRate ?? this.baudRate,
      note: note ?? this.note,
      tag: tag ?? this.tag,
      openCount: openCount ?? this.openCount,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 从数据库行记录解析。
  factory Device.fromMap(Map<String, Object?> map) {
    return Device(
      name: map['name'] as String,
      type: ConnectionType.fromStorage(map['type'] as String),
      host: map['host'] as String,
      port: map['port'] as int,
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      authMethod: AuthMethod.fromStorage(map['auth_method'] as String? ?? ''),
      privateKey: map['private_key'] as String? ?? '',
      privateKeyPassphrase: map['private_key_passphrase'] as String? ?? '',
      hostKey: map['host_key'] as String? ?? '',
      baudRate: map['baud_rate'] as int? ?? 115200,
      note: map['note'] as String? ?? '',
      tag: map['tag'] as String? ?? '',
      openCount: map['open_count'] as int? ?? 0,
      lastConnectedAt: map['last_connected_at'] as int?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  /// 转换为数据库行记录。
  Map<String, Object?> toMap() {
    return {
      'name': name,
      'type': type.storageValue,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'auth_method': authMethod.storageValue,
      'private_key': privateKey,
      'private_key_passphrase': privateKeyPassphrase,
      'host_key': hostKey,
      'baud_rate': baudRate,
      'note': note,
      'tag': tag,
      'open_count': openCount,
      'last_connected_at': lastConnectedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
