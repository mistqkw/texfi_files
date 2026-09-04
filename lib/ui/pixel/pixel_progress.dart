import 'package:flutter/material.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';

/// Полоса прогресса из отдельных ячеек.
///
/// Материаловская `LinearProgressIndicator` — гладкая полоса со скруглёнными
/// концами и плавной интерполяцией; рядом с блочными карточками она
/// единственная выглядит «не отсюда». Здесь заполнение идёт целыми
/// ячейками: видно не только долю, но и шаг, которым она растёт.
///
/// [value] = null — неопределённое состояние (передача началась, объём ещё
/// не известен): по полосе бежит короткая волна.
class PixelProgress extends StatefulWidget {
  const PixelProgress({
    super.key,
    required this.value,
    this.cells = 24,
    this.height = 10,
  });

  final double? value;
  final int cells;
  final double height;

  @override
  State<PixelProgress> createState() => _PixelProgressState();
}

class _PixelProgressState extends State<PixelProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _syncWave();
  }

  @override
  void didUpdateWidget(PixelProgress old) {
    super.didUpdateWidget(old);
    _syncWave();
  }

  /// Волна крутится только в неопределённом состоянии. Как только объём
  /// известен, контроллер останавливается — незачем держать тикер ради
  /// анимации, которую уже не видно.
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
              phase: _wave.value,
              cells: widget.cells,
              fill: colors.accent,
              empty: colors.surfaceVariant,
              edge: colors.divider,
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
    required this.cells,
    required this.fill,
    required this.empty,
    required this.edge,
  });

  final double? value;
  final double phase;
  final int cells;
  final Color fill;
  final Color empty;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    // Между ячейками остаётся зазор в один пиксель — он и делает полосу
    // «набранной из блоков», а не сплошной.
    const gap = 1.0;
    final cell = (size.width - gap * (cells - 1)) / cells;
    if (cell <= 0) return;

    final paint = Paint();
    final filled = value == null ? 0.0 : value!.clamp(0.0, 1.0) * cells;

    for (var i = 0; i < cells; i++) {
      if (value == null) {
        // Волна из трёх ячеек, бегущая по полосе.
        final head = phase * (cells + 3);
        final d = head - i;
        final lit = d >= 0 && d < 3 ? 1 - d / 3 : 0.0;
        paint.color = lit > 0 ? Color.lerp(empty, fill, lit)! : empty;
      } else {
        // Последняя ячейка заполняется частично — по ней видно движение
        // между целыми шагами.
        final d = filled - i;
        paint.color = d >= 1
            ? fill
            : (d <= 0 ? empty : Color.lerp(empty, fill, d)!);
      }
      canvas.drawRect(
        Rect.fromLTWH(i * (cell + gap), 0, cell, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.value != value ||
      old.phase != phase ||
      old.fill != fill ||
      old.empty != empty;
}

/// Строка «идёт передача»: имя, процент и полоса.
class PixelTransferRow extends StatelessWidget {
  const PixelTransferRow({
    super.key,
    required this.title,
    required this.value,
  });

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
                // Табличные цифры: без них процент дёргает строку по ширине
                // на каждом обновлении.
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 9,
                  color: context.colors.accent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: AppRadius.controlTinyAll,
          child: PixelProgress(value: value),
        ),
      ],
    );
  }
}

/// Длительность, за которую полоса догоняет новое значение. Прогресс
/// приходит рывками по мере отправки чанков; без сглаживания полоса
/// прыгает.
const Duration kProgressCatchUp = AppMotion.fast;
