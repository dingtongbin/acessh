// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

/// 3x3 图案锁控件:滑动连接圆点生成图案,支持校验模式与错误提示。
class PatternLock extends StatefulWidget {
  /// 创建图案锁。
  const PatternLock({
    required this.onCompleted,
    this.errorPattern,
    this.size = 280,
    super.key,
  });

  /// 完成一次输入回调(输出 0-8 的路径序号;过短时也会回调)。
  final ValueChanged<List<int>> onCompleted;

  /// 错误图案(校验失败时传入,短暂显示红色后清空)。
  final List<int>? errorPattern;

  /// 控件尺寸。
  final double size;

  @override
  State<PatternLock> createState() => _PatternLockState();
}

class _PatternLockState extends State<PatternLock> {
  final List<int> _selected = [];
  Offset? _currentDrag;

  /// 9 个圆点的中心位置(相对 0,0)。
  static const List<Offset> _dots = [
    Offset(0.2, 0.2),
    Offset(0.5, 0.2),
    Offset(0.8, 0.2),
    Offset(0.2, 0.5),
    Offset(0.5, 0.5),
    Offset(0.8, 0.5),
    Offset(0.2, 0.8),
    Offset(0.5, 0.8),
    Offset(0.8, 0.8),
  ];

  /// 判定吸附近的点。
  int? _dotAt(Offset position, double size) {
    for (var i = 0; i < _dots.length; i++) {
      final dot = _dots[i] * size;
      if ((dot - position).distance <= size * 0.2) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final scheme = Theme.of(context).colorScheme;
    final hasError =
        widget.errorPattern != null && widget.errorPattern!.isNotEmpty;
    final lineColor = hasError ? Colors.red : scheme.primary;
    return GestureDetector(
      onPanStart: (details) => _onStart(details.localPosition, size),
      onPanUpdate: (details) {
        setState(() => _currentDrag = details.localPosition);
        final dot = _dotAt(details.localPosition, size);
        if (dot != null && !_selected.contains(dot)) {
          setState(() => _selected.add(dot));
        }
      },
      onPanEnd: (_) => _finish(),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PatternPainter(
            selected: _selected,
            currentDrag: _currentDrag,
            lineColor: lineColor,
            dotColor: scheme.primary,
          ),
        ),
      ),
    );
  }

  /// 起点落在圆点上时选中。
  void _onStart(Offset position, double size) {
    final dot = _dotAt(position, size);
    if (dot != null) {
      setState(() {
        _selected
          ..clear()
          ..add(dot);
        _currentDrag = position;
      });
    }
  }

  /// 结束输入并回调。
  void _finish() {
    final result = List<int>.of(_selected);
    setState(() {
      _selected.clear();
      _currentDrag = null;
    });
    widget.onCompleted(result);
  }
}

/// 图案锁绘制。
class _PatternPainter extends CustomPainter {
  /// 创建绘制器。
  _PatternPainter({
    required this.selected,
    required this.currentDrag,
    required this.lineColor,
    required this.dotColor,
  });

  /// 已选点序号。
  final List<int> selected;

  /// 当前拖动位置。
  final Offset? currentDrag;

  /// 连线颜色。
  final Color lineColor;

  /// 圆点颜色。
  final Color dotColor;

  /// 圆点位置(相对 0-1)。
  static const List<Offset> _dots = [
    Offset(0.2, 0.2),
    Offset(0.5, 0.2),
    Offset(0.8, 0.2),
    Offset(0.2, 0.5),
    Offset(0.5, 0.5),
    Offset(0.8, 0.5),
    Offset(0.2, 0.8),
    Offset(0.5, 0.8),
    Offset(0.8, 0.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final s = size.width;

    // 连线。
    final path = Path();
    for (var i = 0; i < selected.length; i++) {
      final dot = _dots[selected[i]] * s;
      if (i == 0) {
        path.moveTo(dot.dx, dot.dy);
      } else {
        path.lineTo(dot.dx, dot.dy);
      }
    }
    if (selected.isNotEmpty && currentDrag != null) {
      path.lineTo(currentDrag!.dx, currentDrag!.dy);
    }
    canvas.drawPath(path, paint);

    // 圆点。
    for (var i = 0; i < _dots.length; i++) {
      final dot = _dots[i] * s;
      final isSelected = selected.contains(i);
      canvas.drawCircle(
        dot,
        s * 0.045,
        Paint()..color = isSelected ? lineColor : dotColor,
      );
      if (isSelected) {
        canvas.drawCircle(dot, s * 0.018, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.currentDrag != currentDrag ||
        oldDelegate.lineColor != lineColor;
  }
}
