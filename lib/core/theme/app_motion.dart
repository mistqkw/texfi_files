import 'package:flutter/animation.dart';

/// Длительности и кривые. Ретро-эффекты держим короткими: стилистика
/// должна читаться, а не задерживать пользователя.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);

  /// Короткий удар подтверждения: просадка кнопки, «поп» чекбокса,
  /// вспышка отправленного сообщения.
  static const Duration pop = Duration(milliseconds: 180);

  /// Переход между экранами.
  static const Duration route = Duration(milliseconds: 200);

  /// Разовый акцент — подтверждение отправки файла.
  static const Duration flourish = Duration(milliseconds: 600);

  /// Полный цикл волны сканера при поиске устройств.
  static const Duration scan = Duration(milliseconds: 1400);

  /// Сборка символа на заставке.
  static const Duration boot = Duration(milliseconds: 1150);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;

  /// Задержка между появлением соседних элементов списка.
  static const Duration stagger = Duration(milliseconds: 40);
}
