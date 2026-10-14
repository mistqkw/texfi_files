import 'package:flutter/material.dart';

import 'app_colors_ext.dart';

/// Типографика дизайна «hairline»:
///
///  * **Unbounded** — заголовки и крупные числа;
///  * **JetBrains Mono** — подписи, метки кнопок, номера секций (капслок,
///    разрядка);
///  * **Гротеск** (по умолчанию Inter) — весь текст, который читают:
///    сообщения, имена файлов, списки.
///
/// Все шрифты лежат в `assets/fonts`, а не тянутся по сети: приложение
/// работает в локальной сети без интернета.
const String displayFontFamily = 'Unbounded';
const String monoFontFamily = 'JetBrainsMono';

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

  TextStyle display({
    required double size,
    required Color color,
    double height = 1.15,
    FontWeight weight = FontWeight.w600,
    double spacing = -0.4,
    List<FontFeature> features = const [],
  }) {
    return TextStyle(
      fontFamily: displayFontFamily,
      // В Unbounded нет ни «₽», ни части знаков — их дорисует гротеск.
      fontFamilyFallback: [sansFamily],
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
      fontFeatures: features,
    );
  }

  TextStyle mono({
    required double size,
    required Color color,
    double height = 1.3,
    double spacing = 1.1,
  }) {
    return TextStyle(
      fontFamily: monoFontFamily,
      fontFamilyFallback: [sansFamily],
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color,
      height: height,
      letterSpacing: spacing,
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
    // Крупные числа — объём переданного, счётчик устройств.
    displayMedium: display(
      size: 28,
      weight: FontWeight.w800,
      color: colors.textPrimary,
      height: 1.1,
      spacing: -0.8,
      features: tabular,
    ),
    displaySmall: display(
      size: 18,
      color: colors.textPrimary,
      height: 1.2,
      features: tabular,
    ),
    // Заголовок экрана.
    headlineMedium: display(
      size: 22,
      weight: FontWeight.w800,
      color: colors.textPrimary,
      spacing: -0.6,
    ),
    // Заголовок секции — подпись mono, капслок.
    headlineSmall: mono(size: 11, color: colors.textSecondary, height: 1.5),
    // Метка кнопки.
    labelLarge: mono(size: 11, color: colors.textPrimary),
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
