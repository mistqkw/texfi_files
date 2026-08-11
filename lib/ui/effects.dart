import 'dart:math';
import 'package:flutter/material.dart';

/// Погодный оверлей: снег или дождь поверх ленты.
class WeatherOverlay extends StatefulWidget {
  final int type; // 1=снег, 2=дождь
  const WeatherOverlay({super.key, required this.type});

  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();
  final _rnd = Random(42);
  late final List<_P> _particles;

  @override
  void initState() {
    super.initState();
    final n = widget.type == 1 ? 90 : 140;
    _particles = List.generate(
      n,
      (_) => _P(
        x: _rnd.nextDouble(),
        y: _rnd.nextDouble(),
        speed: 0.4 + _rnd.nextDouble() * 0.8,
        size: widget.type == 1
            ? 1.5 + _rnd.nextDouble() * 3
            : 6 + _rnd.nextDouble() * 10,
        drift: (_rnd.nextDouble() - 0.5) * 0.4,
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _WeatherPainter(_particles, _c.value, widget.type),
        ),
      ),
    );
  }
}

class _P {
  final double x, y, speed, size, drift;
  _P({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.drift,
  });
}

class _WeatherPainter extends CustomPainter {
  final List<_P> ps;
  final double t;
  final int type;
  _WeatherPainter(this.ps, this.t, this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: type == 1 ? 0.85 : 0.5);
    for (final p in ps) {
      final prog = (p.y + t * p.speed) % 1.0;
      final y = prog * size.height;
      final x = ((p.x + p.drift * prog) % 1.0) * size.width;
      if (type == 1) {
        canvas.drawCircle(Offset(x, y), p.size, paint);
      } else {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 1, y + p.size),
          paint..strokeWidth = 1.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) => old.t != t;
}
