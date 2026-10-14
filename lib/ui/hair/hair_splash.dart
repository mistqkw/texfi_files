import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_typography.dart';
import 'hair_icons.dart';

/// Заставка: знак прорисовывается линиями, под ним проявляется имя, затем
/// всё плавно растворяется поверх уже готового приложения.
class HairSplash extends StatefulWidget {
  final Widget child;
  const HairSplash({super.key, required this.child});

  @override
  State<HairSplash> createState() => _HairSplashState();
}

class _HairSplashState extends State<HairSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.boot,
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
    final palette = AppPalettes.dark;
    return Stack(
      children: [
        widget.child,
        // Заставка поверх готового контента: к моменту, когда она уходит,
        // первый кадр приложения уже отрисован, и перехода «в пустоту» нет.
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Последние 20% — растворение.
            final fade = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0);
            final draw = (t / 0.65).clamp(0.0, 1.0);
            final label = ((t - 0.4) / 0.3).clamp(0.0, 1.0);
            return IgnorePointer(
              child: Opacity(
                opacity: fade,
                child: ColoredBox(
                  color: palette.background,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CustomPaint(
                            painter: HairMarkPainter(
                              color: palette.accent,
                              progress: draw,
                              stroke: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Opacity(
                          opacity: label,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - label)),
                            child: Text(
                              'TexFi files',
                              style: TextStyle(
                                fontFamily: displayFontFamily,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                letterSpacing: -0.6,
                                color: palette.textPrimary,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ],
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
