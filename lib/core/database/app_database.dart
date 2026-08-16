// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:sqflite/sqflite.dart';

import '../logging/app_logger.dart';
import '../paths/app_paths.dart';

/// SQLite 数据库单例,负责打开数据库并执行建表与迁移。
///
/// 设备列表已迁移到 TOML 会话文件存储,此库仅保留连接记录表。
class AppDatabase {
  AppDatabase._();

  /// 全局唯一实例。
  static final AppDatabase instance = AppDatabase._();

  /// 当前数据库版本。
  static const int _version = 6;

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
    AppLogger.d('数据库已打开:$path');
  }

  /// 首次创建数据库时执行建表语句。
  Future<void> _onCreate(Database db, int version) async {
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

  /// 数据库升级:
  /// - 版本 6:设备列表已迁移至 TOML 会话文件,移除 devices 表。
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      await db.execute('DROP TABLE IF EXISTS devices');
    }
  }
}
