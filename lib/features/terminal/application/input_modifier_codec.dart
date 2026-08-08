// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// 输入修饰键组合工具。
///
/// 将文本按 Ctrl/Alt 锁定状态转换为终端编码:
/// - Ctrl + a-z → 0x01-0x1A,Ctrl + A-Z → 0x01-0x1A,
///   Ctrl + [\]^_ → 0x1B-0x1F,Ctrl + Space → NUL,Ctrl + ? → DEL;
/// - Alt 前缀 ESC(0x1B),与 Ctrl 组合时顺序为 ESC + 控制字符。
abstract final class InputModifierCodec {
  const InputModifierCodec._();

  /// 应用修饰组合,返回编码后的文本。
  static String apply(String text, {required bool ctrl, required bool alt}) {
    if (!ctrl && !alt) {
      return text;
    }
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      var code = rune;
      if (ctrl) {
        if (code >= 0x61 && code <= 0x7A) {
          // a-z → 0x01-0x1A。
          code = code - 0x61 + 1;
        } else if (code >= 0x41 && code <= 0x5A) {
          // A-Z → 0x01-0x1A。
          code = code - 0x41 + 1;
        } else if (code >= 0x5B && code <= 0x5F) {
          // [ \ ] ^ _ → 0x1B-0x1F。
          code = code - 0x5B + 27;
        } else if (code == 0x20) {
          // Space → NUL。
          code = 0x00;
        } else if (code == 0x3F) {
          // ? → DEL。
          code = 0x7F;
        }
      }
      if (alt) {
        buffer.writeCharCode(0x1B);
      }
      buffer.writeCharCode(code);
    }
    return buffer.toString();
  }
}
