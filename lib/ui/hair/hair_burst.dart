
import 'package:flutter/material.dart';

import '../../core/theme/app_colors_ext.dart';

/// Короткая вспышка «долетело» поверх экрана.
///
/// Передача файла заканчивалась строкой, тихо появившейся в ленте, и
/// системным тостом. Событие, ради которого приложение существует,
/// заслуживает того, чтобы его было видно: из центра разлетаются расходящиеся
/// кольца, в середине проявляется галочка.
///
/// Живёт около 700 мс и снимает себя сам. Показывается через [show], а не
/// вставляется в дерево экрана: оверлей не зависит от того, какой экран
/// сейчас открыт, и не заставляет его перестраиваться.
class HairBurst {
  HairBurst._();

  static void show(BuildContext context) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final colors = context.colors;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BurstLayer(
        color: colors.accent,
        onDone: () {
          // Снимаем в следующем кадре: удалять OverlayEntry прямо из
          // колбэка анимации — значит менять дерево во время его обхода.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (entry.mounted) entry.remove();
          });
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _BurstLayer extends StatefulWidget {
  const _BurstLayer({required this.color, required this.onDone});

  final Color color;
  final VoidCallback onDone;

  @override
  State<_BurstLayer> createState() => _BurstLayerState();
}

class _BurstLayerState extends State<_BurstLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
              return Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: _ParticlePainter(t, widget.color),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final fade = (1 - t).clamp(0.0, 1.0);

    // Кольцо расходится от центра и тает.
    canvas.drawCircle(
      centre,
      size.width * 0.12 + eased * size.width * 0.34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: fade * 0.7),
    );
    // Второе, чуть позже и тоньше.
    final late = Curves.easeOutCubic.transform(((t - 0.15) / 0.85).clamp(0.0, 1.0));
    canvas.drawCircle(
      centre,
      size.width * 0.12 + late * size.width * 0.46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: fade * 0.35),
    );

    // Галочка прорисовывается линией.
    final draw = Curves.easeOutCubic.transform((t / 0.45).clamp(0.0, 1.0));
    if (draw > 0) {
      final a = Offset(size.width * 0.36, size.height * 0.52);
      final b = Offset(size.width * 0.46, size.height * 0.62);
      final c = Offset(size.width * 0.65, size.height * 0.40);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * draw),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t || old.color != color;
}
