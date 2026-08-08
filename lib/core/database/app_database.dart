// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:sqflite/sqflite.dart';

import '../logging/app_logger.dart';
import '../paths/app_paths.dart';

/// SQLite 数据库单例,负责打开数据库并执行建表与迁移。
class AppDatabase {
  AppDatabase._();

  /// 全局唯一实例。
  static final AppDatabase instance = AppDatabase._();

  /// 当前数据库版本。
  static const int _version = 5;

  Database? _database;

  /// 已打开的数据库连接。
  Database get database {
    final db = _database;
    if (db == null) {
      throw StateError('数据库尚未初始化,请先调用 open()');
    }
    return db;
  }

  /// 打开(或首次创建)数据库,建表失败会向上抛出并阻止应用继续。
  Future<void> open() async {
    final path = await AppPaths.databasePath();
    _database = await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
    // 防御性校验:补齐历史库中缺失的列,避免写入报错。
    await _ensureDeviceColumns(_database!);
    AppLogger.d('数据库已打开:$path');
  }

  /// 首次创建数据库时执行建表语句。
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE devices (
        name TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER NOT NULL,
        username TEXT NOT NULL DEFAULT '',
        password TEXT NOT NULL DEFAULT '',
        auth_method TEXT NOT NULL DEFAULT 'password',
        private_key TEXT NOT NULL DEFAULT '',
        private_key_passphrase TEXT NOT NULL DEFAULT '',
        host_key TEXT NOT NULL DEFAULT '',
        baud_rate INTEGER NOT NULL DEFAULT 115200,
        open_count INTEGER NOT NULL DEFAULT 0,
        last_connected_at INTEGER,
        note TEXT NOT NULL DEFAULT '',
        tag TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE connection_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_name TEXT NOT NULL,
        device_type TEXT NOT NULL,
        result TEXT NOT NULL,
        connected_at INTEGER NOT NULL,
        disconnected_at INTEGER
      )
    ''');
  }

  /// 校验 devices 表结构,缺失的列自动补齐(防御历史库结构不完整)。
  Future<void> _ensureDeviceColumns(Database db) async {
    final rows = await db.rawQuery('PRAGMA table_info(devices)');
    final columns = rows.map((row) => row['name'] as String).toSet();
    if (!columns.contains('note')) {
      await db.execute(
        "ALTER TABLE devices ADD COLUMN note TEXT NOT NULL DEFAULT ''",
      );
    }
    if (!columns.contains('private_key_passphrase')) {
      await db.execute(
        "ALTER TABLE devices ADD COLUMN private_key_passphrase "
        "TEXT NOT NULL DEFAULT ''",
      );
    }
    if (!columns.contains('host_key')) {
      await db.execute(
        "ALTER TABLE devices ADD COLUMN host_key TEXT NOT NULL DEFAULT ''",
      );
    }
    if (!columns.contains('tag')) {
      await db.execute(
        "ALTER TABLE devices ADD COLUMN tag TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  /// 数据库升级:
  /// - 版本 2:设备表增加备注列,废弃脚本表(脚本改文件系统存储);
  /// - 版本 3:设备表增加私钥口令列;
  /// - 版本 4:设备表增加 SSH 主机指纹列;
  /// - 版本 5:设备表增加标签列。
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE devices ADD COLUMN note TEXT NOT NULL DEFAULT ''",
      );
      await db.execute('DROP TABLE IF EXISTS scripts');
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE devices ADD COLUMN private_key_passphrase "
        "TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE devices ADD COLUMN host_key TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE devices ADD COLUMN tag TEXT NOT NULL DEFAULT ''",
      );
    }
  }
}
