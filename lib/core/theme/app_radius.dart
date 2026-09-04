import 'package:flutter/widgets.dart';

/// Радиусы двух наборов. Карточки скруглены умеренно (8–12) — читаются как
/// современный интерфейс; кнопки и переключатели почти квадратные (0–4) —
/// держат пиксельную стилистику.
abstract final class AppRadius {
  static const double cardSmall = 8;
  static const double cardMedium = 10;
  static const double cardLarge = 12;

  static const BorderRadius cardSmallAll =
      BorderRadius.all(Radius.circular(cardSmall));
  static const BorderRadius cardMediumAll =
      BorderRadius.all(Radius.circular(cardMedium));
  static const BorderRadius cardLargeAll =
      BorderRadius.all(Radius.circular(cardLarge));

  static const double controlTiny = 2;
  static const double controlSmall = 4;

  static const BorderRadius controlTinyAll =
      BorderRadius.all(Radius.circular(controlTiny));
  static const BorderRadius controlSmallAll =
      BorderRadius.all(Radius.circular(controlSmall));

  /// Толщина пиксельной рамки у кнопок и карточек.
  static const double pixelBorder = 2;

  /// Смещение сплошной ретро-тени.
  static const double pixelShadowOffset = 3;
}
