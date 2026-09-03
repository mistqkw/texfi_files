import 'package:flutter/material.dart';
import 'pixel_theme.dart';

/// Индикатор поиска устройств: концентрические пиксельные «кольца», которые
/// расходятся от центра — радар, а не крутящийся Material-спиннер.
///
/// Кольца рисуются по сетке квадратами и «щёлкают» по шагам сетки, а не
/// плывут непрерывно: непрерывное движение сглаживается субпикселями и
/// выпадает из рубленой пиксельной графики остального интерфейса.
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
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? PixelTheme.accent;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) =>
              CustomPaint(painter: _ScannerPainter(_c.value, color)),
        ),
      ),
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double t;
  final Color color;
  _ScannerPainter(this.t, this.color);

  // Логическая сетка: нечётная, чтобы у радара был ровно один центр.
  static const int _grid = 15;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _grid;
    const center = _grid ~/ 2;
    final paint = Paint();

    // Три волны, разнесённые по фазе на треть периода.
    for (var wave = 0; wave < 3; wave++) {
      final phase = (t + wave / 3) % 1.0;
      // Радиус шагает по целым клеткам — «щелчками», без плавного роста.
      final radius = (phase * (center + 1)).floor();
      if (radius == 0) continue;
      // Чем дальше волна ушла, тем слабее — затухание сигнала.
      final alpha = (1.0 - phase).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: alpha * 0.9);

      for (var y = 0; y < _grid; y++) {
        for (var x = 0; x < _grid; x++) {
          final dx = (x - center).abs();
          final dy = (y - center).abs();
          // Ромбовидное «кольцо» (манхэттенское расстояние) — на пиксельной
          // сетке оно рисуется чисто, без ступенчатых артефактов окружности.
          if (dx + dy == radius) {
            canvas.drawRect(
              Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
              paint,
            );
          }
        }
      }
    }

    // Неподвижная точка в центре — само устройство.
    paint.color = color;
    canvas.drawRect(
      Rect.fromLTWH(center * cell, center * cell, cell + 0.5, cell + 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter old) =>
      old.t != t || old.color != color;
}
