import 'package:flutter/material.dart';
import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_motion.dart';

/// Индикатор поиска устройств: расходящиеся тонкие кольца — видно, что
/// идёт опрос сети, и видно его темп.
class HairScanner extends StatefulWidget {
  final double size;
  final Color? color;

  const HairScanner({super.key, this.size = 72, this.color});

  @override
  State<HairScanner> createState() => _HairScannerState();
}

class _HairScannerState extends State<HairScanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.scan,
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
          painter: _ScanPainter(_c.value, widget.color ?? context.colors.accent),
        ),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  final double t;
  final Color color;
  _ScanPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final max = size.width / 2 - 1;
    // Три кольца, бегущие от центра к краю со сдвигом по фазе.
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final eased = Curves.easeOutCubic.transform(p);
      canvas.drawCircle(
        c,
        max * eased,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: (1 - p) * 0.8),
      );
    }
    canvas.drawCircle(c, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t || old.color != color;
}
