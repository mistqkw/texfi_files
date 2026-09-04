import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Вибро-отклик приложения.
///
/// Тот же подход, что в f0kus: у каждого события свой ритм, а не один
/// универсальный «бз». Но характер здесь другой — это быстрый инструмент,
/// а не игра, поэтому импульсы короче и суше: подтверждение не празднует
/// событие, а сообщает, что действие принято.
///
/// Там, где вибромотора нет (десктоп) или произвольные паттерны не
/// поддерживаются, откатываемся на встроенный [HapticFeedback] — он есть на
/// всех платформах и просто ничего не делает там, где отклик недоступен.
abstract final class Haptics {
  /// Общий выключатель из настроек.
  static bool enabled = true;

  static bool? _hasVibrator;
  static bool? _hasAmplitudeControl;
  static bool? _hasCustomVibrationsSupport;

  /// Опрашивает возможности устройства один раз при старте. Безопасно
  /// вызывать на платформах без плагина — ошибки проглатываются, приложение
  /// остаётся на [HapticFeedback].
  static Future<void> init() async {
    try {
      _hasVibrator = await Vibration.hasVibrator();
      _hasAmplitudeControl = await Vibration.hasAmplitudeControl();
      _hasCustomVibrationsSupport = await Vibration.hasCustomVibrationsSupport();
    } catch (error, stack) {
      debugPrint('Haptics.init failed: $error\n$stack');
      _hasVibrator = false;
      _hasAmplitudeControl = false;
      _hasCustomVibrationsSupport = false;
    }
  }

  static bool get _canPattern =>
      enabled &&
      (_hasVibrator ?? false) &&
      (_hasCustomVibrationsSupport ?? false);

  static Future<void> _pattern(
    List<int> pattern,
    List<int> intensities,
    Future<void> Function() fallback,
  ) async {
    if (!enabled) return;
    if (!_canPattern) {
      await _plainVibrate(pattern, fallback);
      return;
    }
    try {
      await Vibration.vibrate(
        pattern: pattern,
        intensities: (_hasAmplitudeControl ?? false) ? intensities : const [],
      );
    } catch (error) {
      debugPrint('Haptics pattern failed: $error');
      await _plainVibrate(pattern, fallback);
    }
  }

  /// Промежуточная ступень между паттерном и [HapticFeedback].
  ///
  /// Мотор есть, но произвольные паттерны недоступны — тогда лучше отдать
  /// системе одну вибрацию нужной длительности, чем сразу падать на
  /// `HapticFeedback`: тот на части устройств привязан к системному
  /// профилю звука и в беззвучном режиме не делает ничего.
  static Future<void> _plainVibrate(
    List<int> pattern,
    Future<void> Function() fallback,
  ) async {
    if (!(_hasVibrator ?? false)) {
      await fallback();
      return;
    }
    // Нечётные позиции паттерна — импульсы, чётные — паузы между ними.
    var total = 0;
    for (var i = 1; i < pattern.length; i += 2) {
      total += pattern[i];
    }
    if (total <= 0) {
      await fallback();
      return;
    }
    try {
      await Vibration.vibrate(duration: total.clamp(10, 2000));
    } catch (error) {
      debugPrint('Haptics plain vibrate failed: $error');
      await fallback();
    }
  }

  /// Нажатие на кнопку или переключатель. Едва заметный щелчок — он
  /// сопровождает действие, а не объявляет о нём.
  static Future<void> tap() => _pattern(
    const [0, 12],
    const [0, 70],
    HapticFeedback.selectionClick,
  );

  /// Отправка состоялась: два коротких импульса. Не «победа», как в f0kus,
  /// а именно квитанция — ушло.
  static Future<void> sent() => _pattern(
    const [0, 18, 40, 30],
    const [0, 150, 0, 210],
    HapticFeedback.mediumImpact,
  );

  /// В сети появилось новое устройство. Один impulse чуть длиннее нажатия:
  /// это уведомление, которого пользователь не запрашивал, поэтому оно
  /// должно отличаться от отклика на собственное действие.
  static Future<void> peerFound() => _pattern(
    const [0, 22],
    const [0, 120],
    HapticFeedback.lightImpact,
  );

  /// Что-то не получилось: отправка не прошла, файл не открылся.
  static Future<void> failure() => _pattern(
    const [0, 40, 60, 40],
    const [0, 180, 0, 180],
    HapticFeedback.heavyImpact,
  );
}
