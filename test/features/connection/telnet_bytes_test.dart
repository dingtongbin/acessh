// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

import 'package:acessh/features/connection/application/telnet_bytes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TelnetBytes.stripCommands', () {
    test('保留纯文本字节', () {
      final input = utf8.encode('hello world');
      expect(TelnetBytes.stripCommands(input), input);
    });

    test('剥离三字节 IAC 命令(如 WILL/DO)', () {
      // IAC WILL 24(3 字节)夹在文本中。
      final input = [
        ...utf8.encode('a'),
        0xFF,
        0xFB,
        0x18,
        ...utf8.encode('b'),
      ];
      expect(utf8.decode(TelnetBytes.stripCommands(input)), 'ab');
    });

    test('剥离两字节命令(如 NOP)', () {
      final input = [
        0xFF, 0xF1, // IAC NOP
        ...utf8.encode('ok'),
      ];
      expect(utf8.decode(TelnetBytes.stripCommands(input)), 'ok');
    });

    test('跳过 SB 子协商到 IAC SE', () {
      // IAC SB 24 SEND IAC SE 应被整段剥离。
      final input = [
        ...utf8.encode('before'),
        0xFF,
        0xFA,
        0x18,
        0x01,
        0xFF,
        0xF0,
        ...utf8.encode('after'),
      ];
      expect(utf8.decode(TelnetBytes.stripCommands(input)), 'beforeafter');
    });

    test('IAC IAC 转义为单个 0xFF', () {
      final input = [0xFF, 0xFF];
      expect(TelnetBytes.stripCommands(input), [0xFF]);
    });

    test('保留 ANSI 转义序列', () {
      // ANSI 颜色序列 \x1b[31m 与 IAC 无关,必须保留。
      final input = [
        0x1B, 0x5B, 0x33, 0x31, 0x6D, // ESC [ 3 1 m
        ...utf8.encode('red'),
      ];
      expect(utf8.decode(TelnetBytes.stripCommands(input)), '\x1b[31mred');
    });

    test('文本与命令交错时全部剥离', () {
      final input = [
        ...utf8.encode('L'),
        0xFF, 0xFD, 0x01, // DO ECHO
        ...utf8.encode('ogin: '),
        0xFF, 0xFB, 0x03, // WILL SGA
        ...utf8.encode('user'),
      ];
      expect(utf8.decode(TelnetBytes.stripCommands(input)), 'Login: user');
    });

    test('末尾不完整命令丢弃', () {
      expect(TelnetBytes.stripCommands([0xFF]), isEmpty);
      expect(TelnetBytes.stripCommands([0xFF, 0xFB]), isEmpty);
    });

    test('空输入返回空', () {
      expect(TelnetBytes.stripCommands(const []), isEmpty);
    });

    test('子协商未闭合时丢弃其后全部内容', () {
      final input = [
        ...utf8.encode('x'),
        0xFF, 0xFA, 0x18, 0x01, // SB 未闭合
        ...utf8.encode('y'),
      ];
      expect(utf8.decode(TelnetBytes.stripCommands(input)), 'x');
    });
  });
}
