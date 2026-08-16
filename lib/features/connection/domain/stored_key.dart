// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// 全局密钥库中的一条密钥(本机身份,可被多个设备引用)。
class StoredKey {
  /// 创建密钥记录。
  const StoredKey({
    required this.name,
    required this.privateKey,
    required this.passphrase,
    required this.createdAt,
    this.filePath = '',
  });

  /// 密钥名(密钥 JSON 文件名,自动生成)。
  final String name;

  /// OpenSSH 私钥 PEM 内容(内存明文,落盘前由仓库加密)。
  final String privateKey;

  /// 私钥口令(加密私钥才有,非加密私钥为空)。
  final String passphrase;

  /// 创建时间戳(毫秒)。
  final int createdAt;

  /// 密钥 JSON 文件完整路径(内存态,不写入 JSON)。
  final String filePath;

  /// 复制并替换部分字段。
  StoredKey copyWith({String? filePath}) {
    return StoredKey(
      name: name,
      privateKey: privateKey,
      passphrase: passphrase,
      createdAt: createdAt,
      filePath: filePath ?? this.filePath,
    );
  }

  /// 从 JSON 解析。
  factory StoredKey.fromJson(Map<String, dynamic> json) {
    return StoredKey(
      name: json['name'] as String? ?? '',
      privateKey: json['private_key'] as String? ?? '',
      passphrase: json['passphrase'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
    );
  }

  /// 转换为 JSON(敏感字段为加密值,由仓库在写入前加密)。
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'private_key': privateKey,
      'passphrase': passphrase,
      'created_at': createdAt,
    };
  }
}
