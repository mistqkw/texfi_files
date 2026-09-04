import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme/app_colors_ext.dart';

/// Полоса перемотки, набранная из ячеек.
///
/// Материаловский Slider с круглой ручкой и «волной» под пальцем — самая
/// заметная чужеродная деталь в плеере. Здесь ручка квадратная, дорожка
/// блочная, а перемотка работает и по нажатию в точку, и протяжкой.
class PixelSeekBar extends StatefulWidget {
  const PixelSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.cells = 32,
    this.height = 14,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final int cells;
  final double height;

  @override
  State<PixelSeekBar> createState() => _PixelSeekBarState();
}

class _PixelSeekBarState extends State<PixelSeekBar> {
  /// Пока палец на полосе, показываем его позицию, а не приходящую от
  /// плеера: иначе ручка дёргается назад между кадрами перемотки.
  double? _dragged;

  double get _fraction {
    if (_dragged != null) return _dragged!;
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _update(Offset local, double width, {bool commit = false}) {
    if (width <= 0) return;
    final value = (local.dx / width).clamp(0.0, 1.0);
    setState(() => _dragged = value);
    if (commit) {
      final total = widget.duration.inMilliseconds;
      if (total > 0) {
        widget.onSeek(Duration(milliseconds: (value * total).round()));
      }
      Haptics.tap();
      setState(() => _dragged = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _update(d.localPosition, width, commit: true),
          onHorizontalDragUpdate: (d) => _update(d.localPosition, width),
          onHorizontalDragEnd: (_) {
            final value = _dragged;
            if (value == null) return;
            final total = widget.duration.inMilliseconds;
            if (total > 0) {
              widget.onSeek(Duration(milliseconds: (value * total).round()));
            }
            Haptics.tap();
            setState(() => _dragged = null);
          },
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: _SeekPainter(
                fraction: _fraction,
                cells: widget.cells,
                fill: colors.accent,
                empty: colors.surfaceVariant,
                knob: colors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekPainter extends CustomPainter {
  const _SeekPainter({
    required this.fraction,
    required this.cells,
    required this.fill,
    required this.empty,
    required this.knob,
  });

  final double fraction;
  final int cells;
  final Color fill;
  final Color empty;
  final Color knob;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 1.0;
    final cell = (size.width - gap * (cells - 1)) / cells;
    if (cell <= 0) return;
    final filled = fraction * cells;
    final paint = Paint();

    for (var i = 0; i < cells; i++) {
      final d = filled - i;
      paint.color = d >= 1 ? fill : (d <= 0 ? empty : Color.lerp(empty, fill, d)!);
      canvas.drawRect(
        Rect.fromLTWH(i * (cell + gap), size.height * 0.25, cell, size.height * 0.5),
        paint,
      );
    }

    // Квадратная ручка во всю высоту — она же и есть указатель позиции.
    final x = (fraction * (size.width - cell)).clamp(0.0, size.width - cell);
    canvas.drawRect(
      Rect.fromLTWH(x.floorToDouble(), 0, cell.clamp(3.0, 8.0), size.height),
      paint..color = knob,
    );
  }

  @override
  bool shouldRepaint(_SeekPainter old) =>
      old.fraction != fraction || old.fill != fill || old.knob != knob;
}
