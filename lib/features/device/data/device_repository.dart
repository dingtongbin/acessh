// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/device.dart';
import '../domain/device_sort_field.dart';

/// 设备表数据访问,主键为会话名,提供 CRUD、计数与模糊搜索。
class DeviceRepository {
  /// 创建设备仓库;不传数据库时使用全局应用数据库。
  DeviceRepository([Database? database])
    : _database = database ?? AppDatabase.instance.database;

  final Database _database;

  /// 插入新设备;会话名已存在时抛出友好错误。
  Future<void> insert(Device device) async {
    try {
      await _database.insert('devices', device.toMap());
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw StateError('会话名"${device.name}"已存在,请更换名称');
      }
      rethrow;
    }
  }

  /// 按会话名更新设备;会话名不存在时抛出异常。
  Future<void> update(Device device) async {
    final count = await _database.update(
      'devices',
      device.toMap(),
      where: 'name = ?',
      whereArgs: [device.name],
    );
    if (count == 0) {
      throw StateError('设备不存在:${device.name}');
    }
  }

  /// 按会话名删除设备。
  Future<void> delete(String name) async {
    await _database.delete('devices', where: 'name = ?', whereArgs: [name]);
  }

  /// 查询全部设备,按指定字段与方向排序。
  Future<List<Device>> queryAll({
    DeviceSortField sortField = DeviceSortField.createdAt,
    SortDirection direction = SortDirection.descending,
  }) async {
    final orderColumn = switch (sortField) {
      DeviceSortField.createdAt => 'created_at',
      DeviceSortField.openCount => 'open_count',
      DeviceSortField.lastConnectedAt => 'last_connected_at',
    };
    final order = direction == SortDirection.descending ? 'DESC' : 'ASC';
    final rows = await _database.query(
      'devices',
      orderBy: '$orderColumn $order, name ASC',
    );
    return rows.map(Device.fromMap).toList();
  }

  /// 按会话名查询单个设备,不存在返回 null。
  Future<Device?> queryByName(String name) async {
    final rows = await _database.query(
      'devices',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Device.fromMap(rows.first);
  }

  /// 模糊搜索:会话名、主机、用户名任一包含关键字。
  Future<List<Device>> search(String keyword) async {
    final like = '%$keyword%';
    final rows = await _database.query(
      'devices',
      where: 'name LIKE ? OR host LIKE ? OR username LIKE ?',
      whereArgs: [like, like, like],
      orderBy: 'open_count DESC',
    );
    return rows.map(Device.fromMap).toList();
  }

  /// 记录一次成功连接:打开次数 +1 并更新最近登录时间。
  Future<void> recordOpened(String name) async {
    final device = await queryByName(name);
    if (device == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.update(
      'devices',
      {
        'open_count': device.openCount + 1,
        'last_connected_at': now,
        'updated_at': now,
      },
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  /// 保存设备 SSH 主机指纹(首次连接确认后写入)。
  Future<void> saveHostKey(String name, String hostKey) async {
    await _database.update(
      'devices',
      {
        'host_key': hostKey,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  /// 清除设备 SSH 主机指纹(用户主动删除后下次连接重新确认)。
  Future<void> clearHostKey(String name) async {
    await _database.update(
      'devices',
      {'host_key': '', 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'name = ?',
      whereArgs: [name],
    );
  }
}
