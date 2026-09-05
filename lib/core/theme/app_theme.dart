import 'package:flutter/material.dart';

import 'app_colors_ext.dart';
import 'app_palettes.dart';
import 'app_radius.dart';
import 'app_slider_shapes.dart';
import 'app_typography.dart';

/// Сборка ThemeData поверх палитры.
///
/// Карточки и кнопки рисуют рамку и тень сами (см. PixelShadowBox), поэтому
/// материаловские elevation/surfaceTint здесь везде погашены: иначе поверх
/// сплошной ретро-тени ложится ещё и мягкая, и край двоится.
abstract final class AppTheme {
  static ThemeData build({
    required Brightness brightness,
    String sansFamily = defaultSansFamily,
  }) {
    final colors = AppPalettes.forBrightness(brightness);
    final text = buildAppTextTheme(colors: colors, sansFamily: sansFamily);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      error: colors.danger,
      onError: colors.onAccent,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [colors],
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      textTheme: text,
      fontFamily: sansFamily,
      // Материаловская «клякса» под пальцем чужеродна блочным элементам:
      // отклик на нажатие даёт PixelShadowBox, просаживая элемент в тень.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineMedium,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardMediumAll,
          side: BorderSide(
            color: colors.divider,
            width: AppRadius.pixelBorder,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardMediumAll,
          side: BorderSide(
            color: colors.divider,
            width: AppRadius.pixelBorder,
          ),
        ),
        titleTextStyle: text.headlineMedium,
        contentTextStyle: text.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        hintStyle: text.bodyMedium?.copyWith(color: colors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: _fieldBorder(colors.divider),
        enabledBorder: _fieldBorder(colors.divider),
        focusedBorder: _fieldBorder(colors.accent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surfaceVariant,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.controlSmallAll,
          side: BorderSide(color: colors.accent, width: AppRadius.pixelBorder),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 8,
        activeTrackColor: colors.accent,
        inactiveTrackColor: colors.surfaceVariant,
        thumbColor: colors.textPrimary,
        // overlayColor переиспользуется как цвет рамки ручки: у
        // SliderThemeData нет отдельного поля под обводку, а «клякса» под
        // пальцем здесь всё равно отключена.
        overlayColor: colors.divider,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const PixelSliderThumb(),
        trackShape: const PixelSliderTrack(),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        showValueIndicator: ShowValueIndicator.never,
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: AppRadius.pixelBorder,
        space: AppRadius.pixelBorder,
      ),
      // Material-переключатели в интерфейсе не используются (для них есть
      // пиксельные версии), но плагины и системные диалоги могут их
      // показать — пусть хотя бы попадают в палитру.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(colors.textPrimary),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? colors.accent
              : colors.surfaceVariant,
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: AppRadius.controlSmallAll,
    borderSide: BorderSide(color: color, width: AppRadius.pixelBorder),
  );
}

/// Палитра вне дерева виджетов — например, для заставки, которая рисуется
/// до того, как тема применена.
AppColorsExt paletteFor(Brightness brightness) =>
    AppPalettes.forBrightness(brightness);
