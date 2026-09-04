import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Пиксельный снегопад поверх фона.
///
/// Реализация намеренно скупая: один [Ticker], один [CustomPainter] и
/// заранее выделенный массив частиц, который переиспользуется — улетевшая
/// вниз снежинка не удаляется, а возвращается наверх. Частые реализации
/// такого эффекта пересоздают виджеты (или список частиц) на каждом кадре
/// и становятся главной причиной просадок; здесь на кадр приходится только
/// арифметика над готовым массивом.
///
/// Снежинки — квадраты в 1–3 логических пикселя без сглаживания: круглая
/// точка выбивалась бы из пиксельной стилистики.
class PixelSnow extends StatefulWidget {
  const PixelSnow({super.key, required this.speed, this.color});

  /// 0 — медленно, 1 — средне, 2 — быстро.
  final int speed;

  final Color? color;

  @override
  State<PixelSnow> createState() => _PixelSnowState();
}

class _PixelSnowState extends State<PixelSnow>
    with SingleTickerProviderStateMixin {
  /// Плотность подобрана на глаз: заметный снег, но на порядок меньше
  /// частиц, чем в типовых реализациях «на виджетах».
  static const int _count = 70;

  late final Ticker _ticker;
  final _flakes = List.generate(_count, (i) => _Flake.seeded(i));
  final _repaint = ValueNotifier<int>(0);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // Кадр мог быть пропущен (сборка мусора, уход в фон) — не даём частицам
    // прыгнуть через весь экран одним шагом.
    final step = dt.clamp(0.0, 1 / 30);
    final speed = switch (widget.speed) {
      0 => 0.045,
      2 => 0.20,
      _ => 0.10,
    };
    for (final f in _flakes) {
      f.advance(step, speed);
    }
    // Перерисовку запускает ValueNotifier, а не setState: setState
    // пересобирал бы поддерево виджетов 60 раз в секунду, хотя меняются
    // только координаты внутри painter'а.
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Граница перерисовки: снег анимируется постоянно, и без неё каждый
    // его кадр помечал бы к перерисовке весь слой под ним.
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SnowPainter(
            flakes: _flakes,
            repaint: _repaint,
            color: widget.color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Частица. Координаты нормированные (0..1), поэтому не зависят от размера
/// экрана и не требуют пересчёта при повороте.
class _Flake {
  _Flake.seeded(int seed)
    : _rnd = math.Random(seed * 7919),
      x = 0,
      y = 0,
      size = 0,
      drift = 0,
      fall = 0 {
    x = _rnd.nextDouble();
    y = _rnd.nextDouble();
    _respawnParams();
  }

  final math.Random _rnd;
  double x;
  double y;
  double size;
  double drift;
  double fall;
  double _phase = 0;

  void _respawnParams() {
    size = 1 + _rnd.nextInt(3).toDouble();
    // Крупные снежинки падают быстрее — дешёвый намёк на глубину.
    fall = 0.6 + size * 0.25 + _rnd.nextDouble() * 0.3;
    drift = (_rnd.nextDouble() - 0.5) * 0.25;
    _phase = _rnd.nextDouble() * math.pi * 2;
  }

  void advance(double dt, double speed) {
    y += fall * speed * dt;
    _phase += dt * 1.4;
    x += drift * speed * dt + math.sin(_phase) * 0.0006;
    if (y > 1.05) {
      y = -0.05;
      x = _rnd.nextDouble();
      _respawnParams();
    }
    if (x < -0.05) x = 1.05;
    if (x > 1.05) x = -0.05;
  }
}

class _SnowPainter extends CustomPainter {
  _SnowPainter({
    required this.flakes,
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<_Flake> flakes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Одна Paint на весь проход: создание Paint в цикле — заметная доля
    // времени кадра при семидесяти частицах.
    final paint = Paint()..color = color.withValues(alpha: 0.75);
    for (final f in flakes) {
      final px = (f.x * size.width).floorToDouble();
      final py = (f.y * size.height).floorToDouble();
      canvas.drawRect(Rect.fromLTWH(px, py, f.size, f.size), paint);
    }
  }

  @override
  bool shouldRepaint(_SnowPainter old) => old.color != color;
}
