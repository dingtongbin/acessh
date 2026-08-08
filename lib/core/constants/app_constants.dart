// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// 全局常量集中管理,避免散落的魔法值。
abstract final class AppConstants {
  /// 应用展示名。
  static const String appName = 'acessh';

  /// 数据库文件名(存放于系统固定目录)。
  static const String databaseFileName = 'acessh.db';

  /// 私钥导入目录名(存放于系统固定目录)。
  static const String keysDirectoryName = 'keys';

  /// SSH 默认端口。
  static const int defaultSshPort = 22;

  /// Telnet 默认端口。
  static const int defaultTelnetPort = 23;

  /// 串口默认波特率。
  static const int defaultSerialBaudRate = 115200;

  /// 连接超时时长。
  static const Duration connectionTimeout = Duration(seconds: 15);

  /// 终端回滚缓冲行数。
  static const int terminalMaxLines = 1000;

  /// 脚本逐行发送间隔。
  static const Duration scriptLineInterval = Duration(milliseconds: 80);
}
