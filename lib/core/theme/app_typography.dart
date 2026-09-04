import 'package:flutter/material.dart';

import 'app_colors_ext.dart';

/// Типографика собрана из двух шрифтов:
///
///  * **Press Start 2P** — только акцентные элементы: заголовки экранов и
///    секций, короткие метки кнопок, крупные числа. Шрифт очень широкий и
///    нечитаемый в длинных строках.
///  * **Гротеск** (по умолчанию Inter) — весь текст, который читают ради
///    смысла: содержимое сообщений, имена файлов, подписи, списки.
///
/// Оба лежат в `assets/fonts` и объявлены в pubspec, а не тянутся
/// `google_fonts` по сети: приложение работает в локальной сети без
/// интернета, и шрифт, на котором держится вся стилистика, не может
/// зависеть от связи.
const String pixelFontFamily = 'PressStart2P';

/// Гротеск по умолчанию. Пользователь может заменить его в настройках —
/// но только для основного текста, не для акцентных элементов.
const String defaultSansFamily = 'Inter';

/// Варианты основного шрифта, доступные в настройках.
const List<String> sansFamilyChoices = [
  defaultSansFamily,
  'Roboto',
  'monospace',
];

TextTheme buildAppTextTheme({
  required AppColorsExt colors,
  String sansFamily = defaultSansFamily,
}) {
  const tabular = [FontFeature.tabularFigures()];

  TextStyle pixel({
    required double size,
    required Color color,
    double height = 1.4,
    List<FontFeature> features = const [],
  }) {
    return TextStyle(
      fontFamily: pixelFontFamily,
      fontSize: size,
      color: color,
      height: height,
      // Press Start 2P моноширинный и несёт собственный трекинг —
      // дополнительный letterSpacing разваливает слово.
      letterSpacing: 0,
      fontFeatures: features,
    );
  }

  TextStyle sans({
    required double size,
    required FontWeight weight,
    required Color color,
    double height = 1.35,
    List<FontFeature> features = const [],
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      fontFeatures: features,
    );
  }

  return TextTheme(
    // Крупные акцентные числа — объём переданного, счётчик устройств.
    displayMedium: pixel(
      size: 22,
      color: colors.textPrimary,
      height: 1.2,
      features: tabular,
    ),
    displaySmall: pixel(
      size: 14,
      color: colors.textPrimary,
      height: 1.3,
      features: tabular,
    ),
    // Заголовок экрана.
    headlineMedium: pixel(size: 13, color: colors.textPrimary),
    // Заголовок секции.
    headlineSmall: pixel(size: 9, color: colors.accent, height: 1.5),
    // Метка кнопки.
    labelLarge: pixel(size: 9, color: colors.textPrimary, height: 1.3),
    labelMedium: sans(
      size: 12.5,
      weight: FontWeight.w500,
      color: colors.textSecondary,
    ),
    labelSmall: sans(
      size: 11,
      weight: FontWeight.w500,
      color: colors.textTertiary,
    ),
    // Основной текст.
    bodyLarge: sans(
      size: 15.5,
      weight: FontWeight.w400,
      color: colors.textPrimary,
      height: 1.45,
    ),
    bodyMedium: sans(
      size: 14,
      weight: FontWeight.w400,
      color: colors.textPrimary,
      height: 1.45,
    ),
    bodySmall: sans(
      size: 12.5,
      weight: FontWeight.w400,
      color: colors.textSecondary,
      height: 1.4,
    ),
    // Заголовок строки списка — читаемый, не пиксельный.
    titleMedium: sans(
      size: 15,
      weight: FontWeight.w600,
      color: colors.textPrimary,
    ),
    titleSmall: sans(
      size: 13.5,
      weight: FontWeight.w600,
      color: colors.textPrimary,
    ),
  );
}
