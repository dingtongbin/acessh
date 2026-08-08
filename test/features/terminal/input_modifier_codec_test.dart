// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:acessh/features/terminal/application/input_modifier_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InputModifierCodec.apply Ctrl 组合', () {
    test('ctrl + a-z 映射为 0x01-0x1A', () {
      expect(InputModifierCodec.apply('a', ctrl: true, alt: false), '\x01');
      expect(InputModifierCodec.apply('c', ctrl: true, alt: false), '\x03');
      expect(InputModifierCodec.apply('z', ctrl: true, alt: false), '\x1a');
    });

    test('ctrl + A-Z 同样映射为 0x01-0x1A(忽略大小写)', () {
      expect(InputModifierCodec.apply('A', ctrl: true, alt: false), '\x01');
      expect(InputModifierCodec.apply('C', ctrl: true, alt: false), '\x03');
    });

    test('ctrl + [\\]^_ 映射为 0x1B-0x1F', () {
      expect(InputModifierCodec.apply('[', ctrl: true, alt: false), '\x1b');
      expect(InputModifierCodec.apply('_', ctrl: true, alt: false), '\x1f');
    });

    test('ctrl + space 映射为 NUL,ctrl + ? 映射为 DEL', () {
      expect(InputModifierCodec.apply(' ', ctrl: true, alt: false), '\x00');
      expect(InputModifierCodec.apply('?', ctrl: true, alt: false), '\x7f');
    });

    test('ctrl + 数字等不可映射字符保持原样', () {
      expect(InputModifierCodec.apply('5', ctrl: true, alt: false), '5');
      expect(InputModifierCodec.apply('中', ctrl: true, alt: false), '中');
    });
  });

  group('InputModifierCodec.apply Alt 组合', () {
    test('alt + 字符 前缀 ESC', () {
      expect(InputModifierCodec.apply('a', ctrl: false, alt: true), '\x1ba');
      expect(InputModifierCodec.apply('1', ctrl: false, alt: true), '\x1b1');
    });
  });

  group('InputModifierCodec.apply 组合与边界', () {
    test('ctrl + alt 组合:ESC 前缀 + 控制字符', () {
      expect(InputModifierCodec.apply('a', ctrl: true, alt: true), '\x1b\x01');
    });

    test('无修饰时原样返回', () {
      expect(
        InputModifierCodec.apply('hello', ctrl: false, alt: false),
        'hello',
      );
    });

    test('空文本返回空', () {
      expect(InputModifierCodec.apply('', ctrl: true, alt: true), '');
    });

    test('多字符逐个转换', () {
      expect(
        InputModifierCodec.apply('abc', ctrl: true, alt: false),
        '\x01\x02\x03',
      );
    });
  });
}
