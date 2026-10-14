import 'package:flutter/material.dart';

import 'app_radius.dart';

/// Круглая ручка ползунка с рамкой 1px.
class HairSliderThumb extends SliderComponentShape {
  const HairSliderThumb({this.size = 16});

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
    canvas
      ..drawCircle(
        center,
        size / 2,
        Paint()..color = sliderTheme.thumbColor ?? const Color(0xFFFFFFFF),
      )
      ..drawCircle(
        center,
        size / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppRadius.hairline
          ..color = sliderTheme.overlayColor ?? const Color(0x00000000),
      );
  }
}

/// Тонкая дорожка со скруглёнными концами.
class HairSliderTrack extends SliderTrackShape with BaseSliderTrackShape {
  const HairSliderTrack();

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
      ..drawRRect(
        RRect.fromRectAndRadius(left, const Radius.circular(2)),
        Paint()..color = sliderTheme.activeTrackColor ?? const Color(0xFF4A7DFB),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(right, const Radius.circular(2)),
        Paint()
          ..color = sliderTheme.inactiveTrackColor ?? const Color(0xFF2C2C35),
      );
  }
}
