import 'package:flutter/material.dart';

/// Цвета, не зависящие от выбранной темы. Единый источник фирменного
/// акцента для обеих палитр и для мест без доступа к BuildContext.
abstract final class AppColors {
  /// Фирменный синий TexFi. Общий для всей экосистемы.
  static const Color brandBlue = Color(0xFF4A7DFB);

  /// Более глубокий оттенок акцента — рамки и тени пиксельных кнопок.
  static const Color brandBlueDeep = Color(0xFF2B4FB0);

  /// Светлый оттенок акцента — подсветка активных элементов.
  static const Color brandBlueLight = Color(0xFF8FB0FF);
}
