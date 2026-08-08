// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/connection_record.dart';

/// 连接记录表数据访问,记录每次连接的成败与起止时间。
class ConnectionRecordRepository {
  /// 创建连接记录仓库;不传数据库时使用全局应用数据库。
  ConnectionRecordRepository([Database? database])
    : _database = database ?? AppDatabase.instance.database;

  final Database _database;

  /// 记录一次连接开始,返回新记录 id。
  Future<int> recordStart({
    required String deviceName,
    required String deviceType,
  }) async {
    return _database.insert('connection_records', {
      'device_name': deviceName,
      'device_type': deviceType,
      'result': 'connecting',
      'connected_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 更新一次连接的结果与断开时间。
  Future<void> recordEnd({
    required int recordId,
    required bool success,
    int? disconnectedAt,
  }) async {
    await _database.update(
      'connection_records',
      {
        'result': success ? 'success' : 'failed',
        'disconnected_at': disconnectedAt,
      },
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  /// 查询最近 [limit] 条记录,按连接时间倒序。
  Future<List<ConnectionRecord>> queryRecent({int limit = 100}) async {
    final rows = await _database.query(
      'connection_records',
      orderBy: 'connected_at DESC',
      limit: limit,
    );
    return rows.map(ConnectionRecord.fromMap).toList();
  }
}
