import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme/app_colors_ext.dart';

/// Полоса перемотки: тонкая дорожка и круглая ручка. Работает и по
/// нажатию в точку, и протяжкой.
class HairSeekBar extends StatefulWidget {
  const HairSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.height = 14,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final double height;

  @override
  State<HairSeekBar> createState() => _HairSeekBarState();
}

class _HairSeekBarState extends State<HairSeekBar> {
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
    required this.fill,
    required this.empty,
    required this.knob,
  });

  final double fraction;
  final Color fill;
  final Color empty;
  final Color knob;

  @override
  void paint(Canvas canvas, Size size) {
    const track = 3.0;
    const r = 6.0;
    final y = size.height / 2;
    final x = (fraction * (size.width - 2 * r) + r).clamp(r, size.width - r);
    final radius = const Radius.circular(track / 2);
    canvas
      ..drawRRect(
        RRect.fromLTRBR(0, y - track / 2, size.width, y + track / 2, radius),
        Paint()..color = empty,
      )
      ..drawRRect(
        RRect.fromLTRBR(0, y - track / 2, x, y + track / 2, radius),
        Paint()..color = fill,
      )
      ..drawCircle(Offset(x, y), r, Paint()..color = knob)
      ..drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = empty,
      );
  }

  @override
  bool shouldRepaint(_SeekPainter old) =>
      old.fraction != fraction || old.fill != fill || old.knob != knob || old.empty != empty;
}
