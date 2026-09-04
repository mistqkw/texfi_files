import 'package:flutter/material.dart';
import 'pixel_icons.dart';
import 'pixel_theme.dart';

/// Входная анимация: символ приложения (P2P-узел) собирается из отдельных
/// ячеек построчно, затем коротко вспыхивает акцентом.
///
/// Длительность подобрана так, чтобы это читалось как заставка, а не как
/// задержка: ~1.15с целиком, причём последние 200мс — уже уход в контент,
/// поэтому воспринимаемое ожидание меньше секунды.
class PixelSplash extends StatefulWidget {
  final Widget child;
  const PixelSplash({super.key, required this.child});

  @override
  State<PixelSplash> createState() => _PixelSplashState();
}

class _PixelSplashState extends State<PixelSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      children: [
        widget.child,
        // Заставка поверх готового контента: к моменту, когда она уходит,
        // первый кадр приложения уже отрисован, и перехода «в пустоту» нет.
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Последние 18% — растворение.
            final fade = t < 0.82 ? 1.0 : (1 - (t - 0.82) / 0.18).clamp(0.0, 1.0);
            return IgnorePointer(
              child: Opacity(
                opacity: fade,
                child: ColoredBox(
                  color: PixelTheme.darkBg,
                  child: Center(
                    child: CustomPaint(
                      size: const Size(168, 168),
                      painter: _AssemblePainter(t),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AssemblePainter extends CustomPainter {
  final double t;
  _AssemblePainter(this.t);

  static final List<String> _glyph = PixelGlyphs.all['node']!;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = _glyph.length;
    final cols = _glyph.first.length;
    final cell = (size.width / cols).floorToDouble().clamp(1.0, 1e9);
    final dx = ((size.width - cell * cols) / 2).floorToDouble();
    final dy = ((size.height - cell * rows) / 2).floorToDouble();

    // Сборка занимает первые 62% времени, дальше — вспышка и уход.
    final build = (t / 0.62).clamp(0.0, 1.0);
    final flash = t > 0.62 ? ((t - 0.62) / 0.2).clamp(0.0, 1.0) : 0.0;

    final paint = Paint();
    for (var r = 0; r < rows; r++) {
      // Построчно сверху вниз, с небольшим перекрытием строк, чтобы
      // сборка шла волной, а не резкими ступенями.
      final rowStart = r / rows * 0.75;
      final rowProgress = ((build - rowStart) / 0.25).clamp(0.0, 1.0);
      if (rowProgress <= 0) continue;
      final line = _glyph[r];
      for (var c = 0; c < cols; c++) {
        final ch = line.codeUnitAt(c);
        if (ch == 0x2E) continue;
        // Внутри строки ячейки проявляются слева направо.
        if (c / cols > rowProgress) continue;
        paint.color = ch == 0x6F
            ? Colors.white
            : Color.lerp(
                PixelTheme.accent,
                Colors.white,
                flash * (1 - flash) * 2.4,
              )!;
        canvas.drawRect(
          Rect.fromLTWH(dx + c * cell, dy + r * cell, cell - 1, cell - 1),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AssemblePainter old) => old.t != t;
}
