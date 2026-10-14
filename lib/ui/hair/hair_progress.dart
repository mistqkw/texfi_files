import 'package:flutter/material.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';

/// Полоса прогресса: тонкая скруглённая дорожка и заливка акцентом.
/// [value] `null` — неопределённое ожидание: по дорожке бежит отрезок.
class HairProgress extends StatefulWidget {
  const HairProgress({super.key, required this.value, this.height = 4});

  final double? value;
  final double height;

  @override
  State<HairProgress> createState() => _HairProgressState();
}

class _HairProgressState extends State<HairProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _syncWave();
  }

  @override
  void didUpdateWidget(HairProgress old) {
    super.didUpdateWidget(old);
    _syncWave();
  }

  void _syncWave() {
    if (widget.value == null) {
      if (!_wave.isAnimating) _wave.repeat();
    } else if (_wave.isAnimating) {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _wave,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ProgressPainter(
              value: widget.value,
              phase: Curves.easeInOutCubic.transform(_wave.value),
              fill: colors.accent,
              track: colors.surfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.value,
    required this.phase,
    required this.fill,
    required this.track,
  });

  final double? value;
  final double phase;
  final Color fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = track,
    );
    final paint = Paint()..color = fill;
    if (value == null) {
      final seg = size.width * 0.3;
      final left = (size.width + seg) * phase - seg;
      final rect = Rect.fromLTRB(
        left.clamp(0.0, size.width),
        0,
        (left + seg).clamp(0.0, size.width),
        size.height,
      );
      if (rect.width > 0) canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      return;
    }
    final w = size.width * value!.clamp(0.0, 1.0);
    if (w <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w < size.height ? size.height : w, size.height), radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.value != value || old.phase != phase || old.fill != fill || old.track != track;
}

/// Строка передачи: имя, процент и полоса под ним.
class HairTransferRow extends StatelessWidget {
  const HairTransferRow({super.key, required this.title, required this.value});

  final String title;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final percent = value == null ? '' : '${(value! * 100).round()}%';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DefaultTextStyle.of(context).style,
              ),
            ),
            if (percent.isNotEmpty)
              Text(
                percent,
                // Табличные цифры: процент не дёргает строку по ширине.
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 12,
                  color: context.colors.accent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: AppRadius.controlTinyAll,
          child: HairProgress(value: value),
        ),
      ],
    );
  }
}

const Duration kProgressCatchUp = AppMotion.fast;
