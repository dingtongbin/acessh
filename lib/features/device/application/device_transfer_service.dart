// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../domain/device.dart';

/// 设备导出/导入加密服务。
///
/// 导出:设备列表序列化为 JSON,使用密码经 PBKDF2 派生密钥,
/// AES-GCM 加密后封装为 .acessh 文件(JSON 容器:salt/iv/data)。
class DeviceTransferService {
  /// 创建传输服务。
  const DeviceTransferService();

  /// PBKDF2 迭代次数。
  static const int _pbkdf2Iterations = 100000;

  /// 加密并封装设备列表为 .acessh 文件内容。
  ///
  /// [password] 用于派生加密密钥;返回 JSON 文本容器。
  static Future<String> encryptDevices(
    List<Device> devices,
    String password,
  ) async {
    final json = jsonEncode(devices.map((d) => d.toMap()).toList());
    final algorithm = AesGcm.with256bits();
    final salt = algorithm.newNonce();
    final key = await _deriveKey(password, salt);
    final nonce = algorithm.newNonce();
    final encrypted = await algorithm.encrypt(
      utf8.encode(json),
      secretKey: key,
      nonce: nonce,
    );
    return jsonEncode({
      'format': 'acessh-devices-v1',
      'salt': base64Encode(salt),
      'iv': base64Encode(nonce),
      'mac': base64Encode(encrypted.mac.bytes),
      'data': base64Encode(encrypted.cipherText),
    });
  }

  /// 解密 .acessh 文件内容,返回设备列表。
  ///
  /// 密码错误或文件损坏时抛出异常。
  static Future<List<Device>> decryptDevices(
    String content,
    String password,
  ) async {
    final container = jsonDecode(content) as Map<String, dynamic>;
    if (container['format'] != 'acessh-devices-v1') {
      throw const FormatException('不是有效的 acessh 设备文件');
    }
    final salt = base64Decode(container['salt'] as String);
    final iv = base64Decode(container['iv'] as String);
    final mac = base64Decode(container['mac'] as String);
    final data = base64Decode(container['data'] as String);
    final key = await _deriveKey(password, salt);
    final algorithm = AesGcm.with256bits();
    final decrypted = await algorithm.decrypt(
      SecretBox(data, nonce: iv, mac: Mac(mac)),
      secretKey: key,
    );
    final json = utf8.decode(decrypted);
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => Device.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// 由密码与盐派生 256 位密钥。
  static Future<SecretKey> _deriveKey(String password, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }
}
