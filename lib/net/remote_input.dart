import 'dart:io';
import 'package:flutter/foundation.dart';

/// Инъекция ввода на ПК (Linux/Wayland/Hyprland через ydotool).
///
/// Требуется запущенный демон `ydotoold`. Проверяется наличие бинаря.
class RemoteInput {
  static bool get supported => Platform.isLinux;

  static bool? _available;

  /// Окружение с сокетом ydotoold (в GUI-сессии переменной может не быть).
  static Map<String, String> get _env {
    if (Platform.environment.containsKey('YDOTOOL_SOCKET')) return {};
    final uid = _uid();
    final sock = '/run/user/$uid/.ydotool_socket';
    return File(sock).existsSync() ? {'YDOTOOL_SOCKET': sock} : {};
  }

  static String _uid() {
    try {
      final r = Process.runSync('id', ['-u']);
      return (r.stdout as String).trim();
    } catch (_) {
      return '1000';
    }
  }

  /// Проверить, установлен ли ydotool.
  static Future<bool> check() async {
    if (!supported) return false;
    if (_available != null) return _available!;
    try {
      final r = await Process.run('which', ['ydotool']);
      _available = r.exitCode == 0;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  /// Напечатать строку текста как с клавиатуры.
  static Future<bool> typeText(String text) async {
    if (!await check() || text.isEmpty) return false;
    try {
      final r = await Process.run('ydotool', ['type', '--', text],
          environment: _env, includeParentEnvironment: true);
      if (r.exitCode != 0) debugPrint('ydotool type stderr: ${r.stderr}');
      return r.exitCode == 0;
    } catch (e) {
      debugPrint('ydotool ошибка: $e');
      return false;
    }
  }

  // Linux input-event keycodes для спец-клавиш.
  static const _keycodes = <String, int>{
    'enter': 28,
    'backspace': 14,
    'tab': 15,
    'space': 57,
    'esc': 1,
    'up': 103,
    'down': 108,
    'left': 105,
    'right': 106,
    'delete': 111,
    'home': 102,
    'end': 107,
  };

  /// Нажать спец-клавишу по имени (enter, backspace, tab, ...).
  static Future<bool> pressKey(String name) async {
    if (!await check()) return false;
    final code = _keycodes[name.toLowerCase()];
    if (code == null) return false;
    try {
      // <code>:1 = нажатие, <code>:0 = отпускание.
      final r = await Process.run('ydotool', ['key', '$code:1', '$code:0'],
          environment: _env, includeParentEnvironment: true);
      return r.exitCode == 0;
    } catch (e) {
      debugPrint('ydotool key ошибка: $e');
      return false;
    }
  }
}
