import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Глобальные настройки приложения. Максимум опций по просьбе пользователя.
class Settings extends ChangeNotifier {
  final SharedPreferences _p;
  Settings(this._p);

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    final s = Settings(p);
    if (!p.containsKey('deviceId')) {
      await p.setString('deviceId', const Uuid().v4());
    }
    if (!p.containsKey('deviceName')) {
      await p.setString('deviceName', _defaultName());
    }
    return s;
  }

  static String _defaultName() {
    try {
      final host = Platform.localHostname;
      if (host.trim().isNotEmpty) return host;
    } catch (_) {}
    return Platform.isAndroid ? 'Android' : 'Linux';
  }

  String get deviceId => _p.getString('deviceId')!;

  String get deviceName => _p.getString('deviceName')!;
  set deviceName(String v) {
    _p.setString('deviceName', v.trim().isEmpty ? _defaultName() : v.trim());
    notifyListeners();
  }

  // --- Внешний вид ---
  ThemeMode get themeMode =>
      ThemeMode.values[_p.getInt('themeMode') ?? ThemeMode.dark.index];
  set themeMode(ThemeMode v) {
    _p.setInt('themeMode', v.index);
    notifyListeners();
  }

  int get seedColor => _p.getInt('seedColor') ?? 0xFF6C5CE7;
  set seedColor(int v) {
    _p.setInt('seedColor', v);
    notifyListeners();
  }

  bool get pureBlack => _p.getBool('pureBlack') ?? true;
  set pureBlack(bool v) {
    _p.setBool('pureBlack', v);
    notifyListeners();
  }

  double get uiScale => _p.getDouble('uiScale') ?? 1.0;
  set uiScale(double v) {
    _p.setDouble('uiScale', v.clamp(0.8, 1.4));
    notifyListeners();
  }

  // Стиль скругления пузырей: 0 = мягкий, 1 = круглый, 2 = острый.
  int get bubbleStyle => _p.getInt('bubbleStyle') ?? 0;
  set bubbleStyle(int v) {
    _p.setInt('bubbleStyle', v.clamp(0, 2));
    notifyListeners();
  }

  // Компактная плотность (меньше отступы).
  bool get compact => _p.getBool('compact') ?? false;
  set compact(bool v) {
    _p.setBool('compact', v);
    notifyListeners();
  }

  // Фон ленты: 0 = обычный, 1 = мягкий градиент акцента.
  int get chatBackground => _p.getInt('chatBackground') ?? 1;
  set chatBackground(int v) {
    _p.setInt('chatBackground', v.clamp(0, 1));
    notifyListeners();
  }

  // Включить анимации появления.
  bool get animations => _p.getBool('animations') ?? true;
  set animations(bool v) {
    _p.setBool('animations', v);
    notifyListeners();
  }

  /// Радиус пузыря по выбранному стилю.
  double get bubbleRadius => switch (bubbleStyle) {
        1 => 26,
        2 => 8,
        _ => 18,
      };

  // --- Сеть ---
  bool get autoDiscovery => _p.getBool('autoDiscovery') ?? true;
  set autoDiscovery(bool v) {
    _p.setBool('autoDiscovery', v);
    notifyListeners();
  }

  int get discoveryPort => _p.getInt('discoveryPort') ?? 45888;
  set discoveryPort(int v) {
    _p.setInt('discoveryPort', v);
    notifyListeners();
  }

  bool get autoAcceptFiles => _p.getBool('autoAcceptFiles') ?? true;
  set autoAcceptFiles(bool v) {
    _p.setBool('autoAcceptFiles', v);
    notifyListeners();
  }

  // --- Приём ---
  bool get notifyOnReceive => _p.getBool('notifyOnReceive') ?? true;
  set notifyOnReceive(bool v) {
    _p.setBool('notifyOnReceive', v);
    notifyListeners();
  }

  String? get downloadDir => _p.getString('downloadDir');
  set downloadDir(String? v) {
    if (v == null) {
      _p.remove('downloadDir');
    } else {
      _p.setString('downloadDir', v);
    }
    notifyListeners();
  }

  // --- Удалённый ввод ---
  bool get remoteInputEnabled => _p.getBool('remoteInputEnabled') ?? true;
  set remoteInputEnabled(bool v) {
    _p.setBool('remoteInputEnabled', v);
    notifyListeners();
  }

  // --- Плеер ---
  bool get autoplayMedia => _p.getBool('autoplayMedia') ?? false;
  set autoplayMedia(bool v) {
    _p.setBool('autoplayMedia', v);
    notifyListeners();
  }

  double get playerVolume => _p.getDouble('playerVolume') ?? 100.0;
  set playerVolume(double v) {
    _p.setDouble('playerVolume', v.clamp(0, 100));
    notifyListeners();
  }
}
