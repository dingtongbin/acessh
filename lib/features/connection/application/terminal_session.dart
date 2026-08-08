// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/foundation.dart';
import 'package:kterm/kterm.dart';

import '../../device/domain/device.dart';
import '../../terminal/application/input_modifier_codec.dart';
import '../../terminal/application/input_modifier_controller.dart';

/// 会话生命周期状态。
enum TerminalSessionState {
  /// 正在建立连接。
  connecting,

  /// 已连接并可交互。
  connected,

  /// 已挂起为后台会话(连接保持)。
  background,

  /// 已断开,资源已释放。
  disconnected,
}

/// 一次远程会话的抽象:负责 kterm 终端实例与底层传输(SSH/Telnet/串口)之间的桥接。
///
/// 每个会话内部持有独立的 [Terminal] 实例,UI 层通过 [terminal] 渲染;
/// 用户输入经 `onOutput` 回调转发给底层连接,远程数据则写入 [terminal]。
/// 会话状态变化时通知监听者(如断开后 UI 显示重连入口)。
abstract class TerminalSession extends ChangeNotifier {
  /// 本会话对应的设备。
  final Device device;

  /// kterm 终端实例,由子类在构造时创建并桥接输入输出。
  final Terminal terminal;

  /// 当前会话状态。
  TerminalSessionState state = TerminalSessionState.connecting;

  /// 会话显示名:同名设备多个会话时由会话管理器追加 "(N)" 标识,不隐藏。
  String label;

  /// 关联的连接记录 id,由会话管理器写入,用于连接结束后落库。
  int? connectionRecordId;

  /// 本次会话是否成功建立过连接(用于连接记录判定成败,
  /// 避免后台挂起后关闭被误记为失败)。
  bool connectedOnce = false;

  /// 创建会话,并挂接 kterm 终端的输出回调与尺寸变更回调。
  TerminalSession(this.device, this.terminal, {String? label})
    : label = label ?? device.name {
    terminal.onOutput = _handleUserOutput;
    terminal.onResize = _handleResize;
  }

  /// 更新会话状态并通知监听者。
  @protected
  void setState(TerminalSessionState newState) {
    if (state == newState) {
      return;
    }
    state = newState;
    notifyListeners();
  }

  /// 建立底层连接并打通数据通路;失败时抛出异常由调用方处理。
  Future<void> connect();

  /// 重新连接:断开当前连接后重新建立,用于连接中断后的恢复。
  Future<void> reconnect();

  /// 发送用户输入的文本到远程。
  void sendText(String text);

  /// 以脚本方式发送多行内容:逐行追加回车发送,行间有间隔。
  ///
  /// 逐行发送可避免一次写入过大导致服务端处理异常;
  /// 会话未连接时抛出 [StateError]。
  Future<void> sendScript(String content) async {
    if (state != TerminalSessionState.connected) {
      throw StateError('会话未连接,无法执行脚本');
    }
    final lines = content.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      sendText('$line\r');
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  /// 通知远程终端尺寸变化。
  void resize(int columns, int rows);

  /// 关闭连接并释放资源。
  Future<void> close();

  /// 是否仍持有底层连接。
  bool get isAlive => state != TerminalSessionState.disconnected;

  /// kterm 用户输入回调:若修饰键锁定则组合后转发给远程。
  void _handleUserOutput(String output) {
    if (state != TerminalSessionState.connected) {
      return;
    }
    final mods = InputModifierController.instance;
    var text = output;
    if (mods.ctrlLocked || mods.altLocked) {
      text = InputModifierCodec.apply(
        text,
        ctrl: mods.ctrlLocked,
        alt: mods.altLocked,
      );
      mods.reset();
    }
    sendText(text);
  }

  /// kterm 尺寸变化回调:同步远程终端尺寸。
  void _handleResize(int width, int height, int pixelWidth, int pixelHeight) {
    if (state == TerminalSessionState.connected) {
      resize(width, height);
    }
  }
}
