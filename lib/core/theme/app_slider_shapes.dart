import 'package:flutter/material.dart';

import 'app_radius.dart';

/// Квадратная ручка ползунка.
///
/// Круглая ручка Material — единственная мягкая форма, которая оставалась в
/// интерфейсе: настройки масштаба, размытия, затемнения и громкости
/// выглядели чужеродно рядом с блочными карточками и переключателями.
class PixelSliderThumb extends SliderComponentShape {
  const PixelSliderThumb({this.size = 16});

  final double size;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size(size, size);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final half = size / 2;
    final rect = Rect.fromLTWH(
      (center.dx - half).floorToDouble(),
      (center.dy - half).floorToDouble(),
      size,
      size,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(AppRadius.controlTiny),
    );
    canvas
      ..drawRRect(
        rrect,
        Paint()..color = sliderTheme.thumbColor ?? const Color(0xFFFFFFFF),
      )
      // Рамка той же толщины, что у кнопок и карточек.
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppRadius.pixelBorder
          ..color = sliderTheme.overlayColor ?? const Color(0x00000000),
      );
  }
}

/// Прямоугольная дорожка без скруглённых концов.
class PixelSliderTrack extends SliderTrackShape with BaseSliderTrackShape {
  const PixelSliderTrack();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    if (rect.isEmpty) return;
    final canvas = context.canvas;
    final left = textDirection == TextDirection.ltr
        ? Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom)
        : Rect.fromLTRB(thumbCenter.dx, rect.top, rect.right, rect.bottom);
    final right = textDirection == TextDirection.ltr
        ? Rect.fromLTRB(thumbCenter.dx, rect.top, rect.right, rect.bottom)
        : Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom);
    canvas
      ..drawRect(
        left,
        Paint()..color = sliderTheme.activeTrackColor ?? const Color(0xFF4A7DFB),
      )
      ..drawRect(
        right,
        Paint()
          ..color = sliderTheme.inactiveTrackColor ?? const Color(0xFF2C2C35),
      );
  }
}
