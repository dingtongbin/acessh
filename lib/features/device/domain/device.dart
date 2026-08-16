// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import '../../../core/constants/app_constants.dart';
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

  /// 原始类型存储值;仅当 [type] 为 [ConnectionType.unsupported] 时非空,
  /// 用于保留无法识别的类型字符串,避免编辑保存后类型信息丢失。
  final String? originalType;

  /// 所属文件夹(空串 = 根目录);文件夹只体现在存储目录层级,
  /// 不写入 TOML 文件内容。(folder, 会话名) 唯一。
  final String folder;

  /// 引用的全局密钥 JSON 文件完整路径(私钥认证使用,空 = 未引用)。
  final String keyPath;

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
    this.originalType,
    this.folder = '',
    this.keyPath = '',
  });

  /// 是否使用私钥认证。
  bool get usesPrivateKey => authMethod == AuthMethod.privateKey;

  /// 移动端是否支持连接(仅 SSH/Telnet/串口)。
  bool get isSupportedOnMobile => type.isSupportedOnMobile;

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
    String? originalType,
    String? folder,
    String? keyPath,
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
      originalType: originalType ?? this.originalType,
      folder: folder ?? this.folder,
      keyPath: keyPath ?? this.keyPath,
    );
  }

  /// 从数据库/JSON 行记录解析;type 无法识别时归为 unsupported,
  /// 原始类型字符串保存在 [originalType]。
  factory Device.fromMap(Map<String, Object?> map) {
    final type = ConnectionType.fromStorage(map['type'] as String? ?? '');
    return Device(
      name: map['name'] as String,
      type: type,
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
      originalType: type == ConnectionType.unsupported
          ? map['type'] as String?
          : null,
      folder: map['folder'] as String? ?? '',
      keyPath: map['key_path'] as String? ?? '',
    );
  }

  /// 转换为数据库/JSON 行记录。
  Map<String, Object?> toMap() {
    return {
      'name': name,
      'type': originalType ?? type.storageValue,
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
      'folder': folder,
      'key_path': keyPath,
    };
  }

  /// 转换为 TOML 会话文件字段(对齐 AceShell 设计,只写当前类型字段)。
  ///
  /// 时间戳转换为 ISO 8601 字符串;私钥认证时 [keyPath] 引用密钥库中
  /// 的密钥 JSON 文件(与 AceShell 的 key_path 语义一致),明文不入文件;
  /// 密码字段的加密在仓库持久化边界完成,此处保持明文序列化。
  Map<String, Object?> toTomlMap() {
    final map = <String, Object?>{
      'name': name,
      'type': originalType ?? type.storageValue,
      'created_at': _toIsoString(createdAt),
      'updated_at': _toIsoString(updatedAt),
    };
    if (type != ConnectionType.serial) {
      map['host'] = host;
      map['port'] = port;
      map['username'] = username;
      if (type == ConnectionType.ssh || type == ConnectionType.sftp) {
        if (usesPrivateKey) {
          map['auth_mode'] = 'key';
          if (keyPath.isNotEmpty) {
            map['key_path'] = keyPath;
          }
          // 私钥口令随密钥 JSON 存储(加密),不写入会话文件。
        } else {
          map['auth_mode'] = 'password';
          map['password'] = password;
        }
      } else {
        map['password'] = password;
      }
    } else {
      map['device_path'] = host;
      map['baud_rate'] = baudRate;
    }
    if (note.isNotEmpty) {
      map['note'] = note;
    }
    if (tag.isNotEmpty) {
      map['tag'] = tag;
    }
    map['open_count'] = openCount;
    final lastConnected = lastConnectedAt;
    if (lastConnected != null) {
      map['last_connected_at'] = _toIsoString(lastConnected);
    }
    if (hostKey.isNotEmpty) {
      map['host_key'] = hostKey;
    }
    return map;
  }

  /// 从 TOML 会话文件字段解析(宽松读取:缺键用默认值,未知键忽略)。
  ///
  /// [fallbackName] 为文件缺失 name 字段时的回退(通常为文件名);
  /// [folder] 为文件所在文件夹(由仓库按目录层级推导,不写入文件);
  /// [privateKey]/[privateKeyPassphrase] 由仓库按 key_path 加载后注入。
  factory Device.fromTomlMap(
    Map<String, Object?> map, {
    String? fallbackName,
    String folder = '',
    String privateKey = '',
    String privateKeyPassphrase = '',
  }) {
    final type = ConnectionType.fromStorage(map['type'] as String? ?? '');
    final isSerial = type == ConnectionType.serial;
    return Device(
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : fallbackName ?? '',
      type: type,
      host: isSerial
          ? (map['device_path'] as String? ?? map['host'] as String? ?? '')
          : (map['host'] as String? ?? ''),
      port: isSerial ? 0 : (map['port'] as int? ?? 0),
      username: isSerial ? '' : (map['username'] as String? ?? ''),
      password: isSerial || map['auth_mode'] == 'key'
          ? ''
          : (map['password'] as String? ?? ''),
      authMethod: map['auth_mode'] == 'key'
          ? AuthMethod.privateKey
          : AuthMethod.password,
      privateKey: privateKey,
      privateKeyPassphrase: privateKeyPassphrase.isNotEmpty
          ? privateKeyPassphrase
          // 旧格式回退:口令曾写在会话文件的 key_passphrase 字段。
          : (isSerial || map['auth_mode'] != 'key'
                ? ''
                : (map['key_passphrase'] as String? ?? '')),
      hostKey: map['host_key'] as String? ?? '',
      baudRate: isSerial
          ? (map['baud_rate'] as int? ?? AppConstants.defaultSerialBaudRate)
          : AppConstants.defaultSerialBaudRate,
      note: map['note'] as String? ?? '',
      tag: map['tag'] as String? ?? '',
      openCount: map['open_count'] as int? ?? 0,
      lastConnectedAt: _parseIsoMillis(map['last_connected_at'] as String?),
      createdAt: _parseIsoMillis(map['created_at'] as String?) ?? 0,
      updatedAt: _parseIsoMillis(map['updated_at'] as String?) ?? 0,
      originalType: type == ConnectionType.unsupported
          ? map['type'] as String?
          : null,
      folder: folder,
      keyPath: map['key_path'] as String? ?? '',
    );
  }

  /// 毫秒时间戳转 ISO 8601 字符串。
  static String _toIsoString(int millis) {
    return DateTime.fromMillisecondsSinceEpoch(millis).toIso8601String();
  }

  /// 解析 ISO 8601 字符串为毫秒时间戳,无法解析返回 null。
  static int? _parseIsoMillis(String? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal().millisecondsSinceEpoch;
  }
}
