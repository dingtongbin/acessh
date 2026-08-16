// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:acessh/features/connection/application/ssh_key_deployer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SshKeyDeployer.buildCommand', () {
    const publicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxx acessh';

    test('包含目录创建、权限设置与公钥追加', () {
      final command = SshKeyDeployer.buildCommand(publicKey);
      expect(command, contains('mkdir -p ~/.ssh'));
      expect(command, contains('chmod 700 ~/.ssh'));
      expect(command, contains('touch ~/.ssh/authorized_keys'));
      expect(command, contains('chmod 600 ~/.ssh/authorized_keys'));
      expect(command, contains("grep -qF '$publicKey'"));
      expect(command, contains("echo '$publicKey' >> ~/.ssh/authorized_keys"));
    });

    test('公钥含单引号时正确转义,避免破坏 shell 命令', () {
      const tricky = "ssh-ed25519 AAAAB'C acessh";
      final command = SshKeyDeployer.buildCommand(tricky);
      // 单引号被转义为 '\''(结束引号+字面引号+重新开始引号)。
      expect(command, contains(r"AAAAB'\''C"));
    });

    test('追加是幂等的:先 grep 去重,不存在才追加', () {
      final command = SshKeyDeployer.buildCommand(publicKey);
      expect(command, contains('{ grep -qF'));
      expect(command, contains('||'));
    });
  });
}
