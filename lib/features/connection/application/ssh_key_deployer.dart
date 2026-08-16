// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import '../../../core/constants/app_constants.dart';

/// SSH 公钥部署服务:用密码登录目标服务器,把公钥追加到
/// `~/.ssh/authorized_keys`(等价于 ssh-copy-id)。
///
/// 仅追加不覆盖;公钥已存在时跳过,重复部署是幂等的。
class SshKeyDeployer {
  const SshKeyDeployer._();

  /// 构建部署命令:创建目录与文件、设置权限、追加公钥(已存在则跳过)。
  ///
  /// [publicKey] 为 authorized_keys 公钥行,如 `ssh-ed25519 AAAA… acessh`。
  static String buildCommand(String publicKey) {
    final escaped = publicKey.replaceAll("'", r"'\''");
    return "mkdir -p ~/.ssh && chmod 700 ~/.ssh && "
        "touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && "
        "{ grep -qF '$escaped' ~/.ssh/authorized_keys || "
        "echo '$escaped' >> ~/.ssh/authorized_keys; }";
  }

  /// 用密码登录服务器并部署公钥,返回远程命令退出码(0 表示成功)。
  ///
  /// 认证失败(账户/密码错误)或连接失败时抛出异常。
  static Future<int> deploy({
    required String host,
    required int port,
    required String username,
    required String password,
    required String publicKey,
  }) async {
    final socket = await SSHSocket.connect(
      host,
      port,
      timeout: AppConstants.connectionTimeout,
    );
    final client = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => password,
      authTimeout: AppConstants.connectionTimeout,
      handshakeTimeout: AppConstants.connectionTimeout,
    );
    try {
      final session = await client.execute(buildCommand(publicKey));
      // 收集 stderr 供失败时给出可读原因。
      final stderrBuffer = StringBuffer();
      session.stderr.listen(
        (data) => stderrBuffer.write(utf8.decode(data, allowMalformed: true)),
      );
      await session.done;
      final exitCode = session.exitCode ?? 0;
      if (exitCode != 0) {
        throw StateError('服务器命令执行失败:${stderrBuffer.toString().trim()}');
      }
      return exitCode;
    } finally {
      client.close();
    }
  }
}
