// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:acessh/features/connection/application/telnet_login_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TelnetLoginDetector', () {
    test('检测 login 提示后自动发送用户名和密码', () {
      final detector = TelnetLoginDetector(
        username: 'telnet',
        password: 'secret',
      );
      final sent = <String>[];

      detector.process('Welcome\r\nlogin: ', onSend: sent.add);
      expect(sent, ['telnet\r\n']);
      expect(detector.isCompleted, isFalse);

      detector.process('Password: ', onSend: sent.add);
      expect(sent, ['telnet\r\n', 'secret\r\n']);
      expect(detector.isCompleted, isTrue);
    });

    test('提示文本不区分大小写', () {
      final detector = TelnetLoginDetector(username: 'u1', password: 'p1');
      final sent = <String>[];

      detector.process('LOGIN: ', onSend: sent.add);
      expect(sent, ['u1\r\n']);
      detector.process('PASSWORD: ', onSend: sent.add);
      expect(sent, ['u1\r\n', 'p1\r\n']);
    });

    test('登录完成后不再响应任何提示', () {
      final detector = TelnetLoginDetector(username: 'u1', password: 'p1');
      final sent = <String>[];

      detector.process('login:', onSend: sent.add);
      detector.process('Password:', onSend: sent.add);
      expect(detector.isCompleted, isTrue);

      detector.process('login:', onSend: sent.add);
      expect(sent, ['u1\r\n', 'p1\r\n']);
    });

    test('用户名和密码各只发送一次', () {
      final detector = TelnetLoginDetector(username: 'u1', password: 'p1');
      final sent = <String>[];

      detector.process('login: login: ', onSend: sent.add);
      expect(sent, ['u1\r\n']);
    });

    test('无提示时不发送任何内容', () {
      final detector = TelnetLoginDetector(username: 'u1', password: 'p1');
      final sent = <String>[];

      detector.process('plain output without prompts', onSend: sent.add);
      expect(sent, isEmpty);
      expect(detector.isCompleted, isFalse);
    });

    test('reset 后可以再次自动登录', () {
      final detector = TelnetLoginDetector(username: 'u1', password: 'p1');
      final sent = <String>[];

      detector.process('login:', onSend: sent.add);
      detector.process('Password:', onSend: sent.add);
      detector.reset();
      expect(detector.isCompleted, isFalse);

      detector.process('login:', onSend: sent.add);
      expect(sent, ['u1\r\n', 'p1\r\n', 'u1\r\n']);
    });

    test('用户名未配置时跳过用户名输入', () {
      final detector = TelnetLoginDetector(username: '', password: 'p1');
      final sent = <String>[];

      detector.process('login: ', onSend: sent.add);
      expect(sent, isEmpty);

      detector.process('Password: ', onSend: sent.add);
      expect(sent, ['p1\r\n']);
      expect(detector.isCompleted, isTrue);
    });

    test('密码未配置时跳过密码输入', () {
      final detector = TelnetLoginDetector(username: 'u1', password: '');
      final sent = <String>[];

      detector.process('login: ', onSend: sent.add);
      expect(sent, ['u1\r\n']);

      detector.process('Password: ', onSend: sent.add);
      expect(sent, ['u1\r\n']);
      expect(detector.isCompleted, isTrue);
    });

    test('用户名密码均未配置时始终不发送', () {
      final detector = TelnetLoginDetector(username: '', password: '');
      final sent = <String>[];

      detector.process('login: Password: ', onSend: sent.add);
      expect(sent, isEmpty);
      expect(detector.isCompleted, isTrue);
    });
  });
}
