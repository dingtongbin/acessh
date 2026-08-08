// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// 一次连接的记录。
class ConnectionRecord {
  /// 记录自增主键。
  final int id;

  /// 设备会话名。
  final String deviceName;

  /// 设备类型存储值(ssh/telnet/serial)。
  final String deviceType;

  /// 连接结果(success/failed/connecting)。
  final String result;

  /// 连接开始时间戳(毫秒)。
  final int connectedAt;

  /// 断开时间戳(毫秒),未断开为 null。
  final int? disconnectedAt;

  /// 创建连接记录。
  const ConnectionRecord({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.result,
    required this.connectedAt,
    required this.disconnectedAt,
  });

  /// 是否连接成功。
  bool get isSuccess => result == 'success';

  /// 从数据库行记录解析。
  factory ConnectionRecord.fromMap(Map<String, Object?> map) {
    return ConnectionRecord(
      id: map['id'] as int,
      deviceName: map['device_name'] as String,
      deviceType: map['device_type'] as String,
      result: map['result'] as String,
      connectedAt: map['connected_at'] as int,
      disconnectedAt: map['disconnected_at'] as int?,
    );
  }
}
