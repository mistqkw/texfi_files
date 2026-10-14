import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_colors_ext.dart';

/// Две палитры приложения — те же, что во всей экосистеме TexFi: тёмная
/// (графитовая, синий акцент) и светлая (нейтральная, не «бумажная»).
abstract final class AppPalettes {
  static const AppColorsExt dark = AppColorsExt(
    background: Color(0xFF0A0A0C),
    surface: Color(0xFF111114),
    surfaceVariant: Color(0xFF18181C),
    divider: Color(0xFF26262C),
    accent: AppColors.brandBlue,
    onAccent: Color(0xFF06070C),
    textPrimary: Color(0xFFF4F4F6),
    textSecondary: Color(0xFFA3A3AD),
    textTertiary: Color(0xFF6B6B76),
    success: Color(0xFF3ED598),
    warning: Color(0xFFFFB648),
    danger: Color(0xFFFF6B6B),
  );

  static const AppColorsExt light = AppColorsExt(
    background: Color(0xFFF6F6F3),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEFEFEB),
    divider: Color(0xFFDCDCD6),
    accent: AppColors.brandBlue,
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0C0C0F),
    textSecondary: Color(0xFF55555E),
    textTertiary: Color(0xFF8A8A92),
    success: Color(0xFF1B9E66),
    warning: Color(0xFFD98A2B),
    danger: Color(0xFFD64545),
  );

  static AppColorsExt forBrightness(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;
}
