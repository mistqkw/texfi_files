import 'package:flutter/widgets.dart';

/// Радиусы дизайна «hairline»: карточки мягче, управление почти прямое.
abstract final class AppRadius {
  static const double cardSmall = 6;
  static const double cardMedium = 10;
  static const double cardLarge = 14;

  static const BorderRadius cardSmallAll =
      BorderRadius.all(Radius.circular(cardSmall));
  static const BorderRadius cardMediumAll =
      BorderRadius.all(Radius.circular(cardMedium));
  static const BorderRadius cardLargeAll =
      BorderRadius.all(Radius.circular(cardLarge));

  static const double controlTiny = 2;
  static const double controlSmall = 3;

  static const BorderRadius controlTinyAll =
      BorderRadius.all(Radius.circular(controlTiny));
  static const BorderRadius controlSmallAll =
      BorderRadius.all(Radius.circular(controlSmall));

  /// Толщина тонкой рамки у кнопок и карточек.
  static const double hairline = 1;
}
