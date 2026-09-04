import 'package:flutter/material.dart';
import 'pixel_theme.dart';

/// Индикатор поиска устройств.
///
/// Материаловский CircularProgressIndicator в этом интерфейсе выглядит
/// чужеродно и, что важнее, ничего не сообщает: он крутится одинаково и
/// когда идёт опрос сети, и когда всё зависло. Здесь — расходящиеся
/// концентрические кольца из квадратных ячеек: видно, что идёт волна
/// опроса, и видно её темп.
class PixelScanner extends StatefulWidget {
  final double size;
  final Color? color;

  const PixelScanner({super.key, this.size = 72, this.color});

  @override
  State<PixelScanner> createState() => _PixelScannerState();
}

class _PixelScannerState extends State<PixelScanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ScanPainter(_c.value, widget.color ?? PixelTheme.accent),
        ),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  final double t;
  final Color color;
  _ScanPainter(this.t, this.color);

  /// Сетка кольца. Нечётная, чтобы был настоящий центральный пиксель.
  static const int grid = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = (size.width / grid).floorToDouble().clamp(1.0, 1e9);
    final origin = ((size.width - cell * grid) / 2).floorToDouble();
    const c = grid ~/ 2;
    final paint = Paint();

    for (var y = 0; y < grid; y++) {
      for (var x = 0; x < grid; x++) {
        // Кольцо по «шахматной» метрике — расходится квадратами, а не
        // окружностями: круг на такой сетке разваливается в зубцы.
        final ring = (x - c).abs() > (y - c).abs()
            ? (x - c).abs()
            : (y - c).abs();
        if (ring == 0) {
          paint.color = color;
        } else {
          // Волна: фаза зависит от номера кольца, поэтому подсветка
          // уходит от центра к краю.
          final phase = (t * grid - ring) % grid / grid;
          final lit = phase < 0.28 ? (1 - phase / 0.28) : 0.0;
          if (lit <= 0.02) continue;
          paint.color = color.withValues(alpha: lit * 0.9);
        }
        canvas.drawRect(
          Rect.fromLTWH(origin + x * cell, origin + y * cell, cell - 1, cell - 1),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t || old.color != color;
}
