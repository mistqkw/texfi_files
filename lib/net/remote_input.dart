import 'dart:io';
import 'package:flutter/foundation.dart';

/// Инъекция ввода на ПК (Linux/Wayland/Hyprland).
///
/// Предпочитаем `wtype` — он умеет Unicode (кириллицу, эмодзи) нативно через
/// Wayland virtual-keyboard и не требует демона. Фолбэк — `ydotool` (только
/// латиница, нужен ydotoold).
class RemoteInput {
  static bool get supported => Platform.isLinux;

  static bool? _wtype;
  static bool? _ydotool;

  static Future<bool> _has(String bin) async {
    try {
      final r = await Process.run('which', [bin]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _hasWtype() async => _wtype ??= await _has('wtype');
  static Future<bool> _hasYdotool() async => _ydotool ??= await _has('ydotool');

  /// Доступен ли хоть какой-то способ ввода.
  static Future<bool> check() async {
    if (!supported) return false;
    return (await _hasWtype()) || (await _hasYdotool());
  }

  /// Читаемое имя используемого движка (для настроек).
  static Future<String> engine() async {
    if (!supported) return 'только на Linux';
    if (await _hasWtype()) return 'wtype (Unicode ✓)';
    if (await _hasYdotool()) return 'ydotool (без кириллицы)';
    return 'не найден (нужен wtype)';
  }

  // ── ydotool: окружение с сокетом ──
  static Map<String, String> get _ydotoolEnv {
    if (Platform.environment.containsKey('YDOTOOL_SOCKET')) return {};
    final sock = '/run/user/${_uid()}/.ydotool_socket';
    return File(sock).existsSync() ? {'YDOTOOL_SOCKET': sock} : {};
  }

  static String _uid() {
    try {
      return (Process.runSync('id', ['-u']).stdout as String).trim();
    } catch (_) {
      return '1000';
    }
  }

  /// Напечатать произвольный текст (в т.ч. кириллицу).
  static Future<bool> typeText(String text) async {
    if (text.isEmpty) return true;
    if (await _hasWtype()) {
      return _run('wtype', [text]);
    }
    if (await _hasYdotool()) {
      return _run('ydotool', ['type', '--', text], env: _ydotoolEnv);
    }
    return false;
  }

  // Имя клавиши -> keysym для wtype.
  static const _wtypeKeys = <String, String>{
    'enter': 'Return',
    'backspace': 'BackSpace',
    'tab': 'Tab',
    'esc': 'Escape',
    'space': 'space',
    'up': 'Up',
    'down': 'Down',
    'left': 'Left',
    'right': 'Right',
    'delete': 'Delete',
    'home': 'Home',
    'end': 'End',
  };

  // Имя клавиши -> Linux input keycode для ydotool.
  static const _ydKeys = <String, int>{
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

  /// Нажать спец-клавишу [count] раз (например backspace ×N — одним вызовом).
  static Future<bool> pressKey(String name, {int count = 1}) async {
    final n = count.clamp(1, 500);
    final key = name.toLowerCase();
    if (await _hasWtype()) {
      final sym = _wtypeKeys[key];
      if (sym == null) return false;
      final args = <String>[];
      for (var i = 0; i < n; i++) {
        args
          ..add('-k')
          ..add(sym);
      }
      return _run('wtype', args);
    }
    if (await _hasYdotool()) {
      final code = _ydKeys[key];
      if (code == null) return false;
      final args = <String>['key'];
      for (var i = 0; i < n; i++) {
        args
          ..add('$code:1')
          ..add('$code:0');
      }
      return _run('ydotool', args, env: _ydotoolEnv);
    }
    return false;
  }

  static Future<bool> _run(String bin, List<String> args,
      {Map<String, String>? env}) async {
    try {
      final r = await Process.run(bin, args,
          environment: env, includeParentEnvironment: true);
      if (r.exitCode != 0) debugPrint('$bin err: ${r.stderr}');
      return r.exitCode == 0;
    } catch (e) {
      debugPrint('$bin запуск не удался: $e');
      return false;
    }
  }
}
