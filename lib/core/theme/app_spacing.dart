import 'package:flutter/widgets.dart';

/// Единая шкала отступов — сетка 4pt. Все расстояния берутся отсюда, а не
/// подбираются на глаз.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double page = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 40;

  /// Нижний отступ ленты: поле ввода закреплено снизу и не должно
  /// перекрывать последний элемент.
  static const double composerSafeBottom = 96;

  static const EdgeInsets screen = EdgeInsets.fromLTRB(page, sm, page, xxl);
  static const EdgeInsets card = EdgeInsets.all(lg);

  static const Widget gapXs = SizedBox(height: xs);
  static const Widget gapSm = SizedBox(height: sm);
  static const Widget gapMd = SizedBox(height: md);
  static const Widget gapLg = SizedBox(height: lg);
  static const Widget gapXl = SizedBox(height: xl);
  static const Widget gapXxl = SizedBox(height: xxl);

  static const Widget wGapXs = SizedBox(width: xs);
  static const Widget wGapSm = SizedBox(width: sm);
  static const Widget wGapMd = SizedBox(width: md);
  static const Widget wGapLg = SizedBox(width: lg);
}
