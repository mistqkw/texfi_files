import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors_ext.dart';
import 'pixel_icons.dart';

/// Короткая вспышка «долетело» поверх экрана.
///
/// Передача файла заканчивалась строкой, тихо появившейся в ленте, и
/// системным тостом. Событие, ради которого приложение существует,
/// заслуживает того, чтобы его было видно: из центра разлетаются пиксельные
/// частицы, в середине проявляется галочка.
///
/// Живёт около 700 мс и снимает себя сам. Показывается через [show], а не
/// вставляется в дерево экрана: оверлей не зависит от того, какой экран
/// сейчас открыт, и не заставляет его перестраиваться.
class PixelBurst {
  PixelBurst._();

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

  /// Частицы разложены по кругу заранее и на каждом кадре только
  /// пересчитывают радиус — списка объектов здесь нет вовсе.
  static const int _count = 12;

  static final List<String> _check = PixelGlyphs.all['check']!;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    // Разлёт замедляется к концу: рывок в начале, затухание в конце.
    final eased = 1 - math.pow(1 - t.clamp(0.0, 1.0), 3).toDouble();
    final radius = eased * size.width * 0.42;
    final paint = Paint()..color = color.withValues(alpha: (1 - t).clamp(0, 1));

    for (var i = 0; i < _count; i++) {
      final angle = i * 2 * math.pi / _count;
      // Квадраты, а не точки: круглая частица на пиксельной сетке
      // размывается в пятно.
      final side = i.isEven ? 6.0 : 4.0;
      final dx = centre.dx + math.cos(angle) * radius;
      final dy = centre.dy + math.sin(angle) * radius;
      canvas.drawRect(
        Rect.fromLTWH(dx.floorToDouble(), dy.floorToDouble(), side, side),
        paint,
      );
    }

    _paintCheck(canvas, size);
  }

  /// Галочка «собирается» построчно сверху вниз (слева направо внутри
  /// строки) — та же техника, что у сборки знака на заставке
  /// (pixel_splash.dart), а не плавные Opacity+Transform.scale, как было
  /// раньше. Плавное масштабирование растрового виджета — ровно тот
  /// материаловский приём, которого пиксельная стилистика избегает везде
  /// остальных местах; здесь он был единственным исключением.
  void _paintCheck(Canvas canvas, Size size) {
    // Собирается с 0.25 по 0.62 (та же вторая четверть, что раньше), затем
    // держится и гаснет вместе с частицами.
    final build = ((t - 0.25) / 0.37).clamp(0.0, 1.0);
    if (build <= 0) return;

    final rows = _check.length;
    final cols = _check.first.length;
    const glyphSize = 56.0;
    final cell = (glyphSize / cols).floorToDouble().clamp(1.0, 1e9);
    final dx = (size.width - cell * cols) / 2;
    final dy = (size.height - cell * rows) / 2;
    // Своя, непрозрачная заливка — а не paint частиц: у того альфа
    // непрерывно убывает вместе с их разлётом (color.withValues(alpha:
    // 1-t)), и переиспользование того же Paint погасило бы галочку задолго
    // до её полной сборки. Общее затухание в конце даёт внешний Opacity
    // вокруг всего CustomPaint — на неё это не влияет.
    final paint = Paint()..color = color;

    for (var r = 0; r < rows; r++) {
      final rowStart = r / rows * 0.7;
      final rowProgress = ((build - rowStart) / 0.3).clamp(0.0, 1.0);
      if (rowProgress <= 0) continue;
      final line = _check[r];
      for (var c = 0; c < cols; c++) {
        if (line.codeUnitAt(c) == 0x2E) continue; // '.'
        if (c / cols > rowProgress) continue;
        canvas.drawRect(
          Rect.fromLTWH(dx + c * cell, dy + r * cell, cell - 0.5, cell - 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t || old.color != color;
}
