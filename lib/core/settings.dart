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

  // Язык интерфейса: 'system' | 'en' | 'ru' | 'de' | 'pl'.
  String get localeCode => _p.getString('localeCode') ?? 'system';
  set localeCode(String v) {
    _p.setString('localeCode', v);
    notifyListeners();
  }

  static const supportedLangs = ['en', 'ru', 'de', 'pl'];

  /// Фактический код языка с учётом системного.
  String get effectiveLanguageCode {
    if (localeCode != 'system') return localeCode;
    try {
      final sys =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      return supportedLangs.contains(sys) ? sys : 'en';
    } catch (_) {
      return 'en';
    }
  }

  // Показан ли приветственный экран (онбординг).
  bool get onboardingSeen => _p.getBool('onboardingSeen') ?? false;
  set onboardingSeen(bool v) {
    _p.setBool('onboardingSeen', v);
    notifyListeners();
  }

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

  int get seedColor => _p.getInt('seedColor') ?? 0xFF4C7CFF; // Signal Blue (на тёмном)
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

  // Дизайн-пресет (скин): 0=Material, 1=Apple, 2=Samsung, 3=Windows.
  int get designPreset => _p.getInt('designPreset') ?? 0;
  set designPreset(int v) {
    _p.setInt('designPreset', v.clamp(0, 3));
    notifyListeners();
  }

  // Шрифт: 0=обычный, 1=с засечками, 2=моноширинный.
  int get fontChoice => _p.getInt('fontChoice') ?? 0;
  set fontChoice(int v) {
    _p.setInt('fontChoice', v.clamp(0, 2));
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

  // Своё фото-фон ленты (путь). null = нет.
  String? get chatBgImage => _p.getString('chatBgImage');
  set chatBgImage(String? v) {
    if (v == null) {
      _p.remove('chatBgImage');
    } else {
      _p.setString('chatBgImage', v);
    }
    notifyListeners();
  }

  // Эффект фото-фона: 0=нет, 1=блюр, 2=пиксели.
  int get bgEffect => _p.getInt('bgEffect') ?? 0;
  set bgEffect(int v) {
    _p.setInt('bgEffect', v.clamp(0, 2));
    notifyListeners();
  }

  // Затемнение фона 0..0.8.
  double get bgDim => _p.getDouble('bgDim') ?? 0.35;
  set bgDim(double v) {
    _p.setDouble('bgDim', v.clamp(0, 0.8));
    notifyListeners();
  }

  // Погодный эффект: 0=нет, 1=снег, 2=дождь.
  int get weather => _p.getInt('weather') ?? 0;
  set weather(int v) {
    _p.setInt('weather', v.clamp(0, 2));
    notifyListeners();
  }

  double get weatherSize => _p.getDouble('weatherSize') ?? 1.0;
  set weatherSize(double v) {
    _p.setDouble('weatherSize', v.clamp(0.5, 2.5));
    notifyListeners();
  }

  double get weatherDensity => _p.getDouble('weatherDensity') ?? 1.0;
  set weatherDensity(double v) {
    _p.setDouble('weatherDensity', v.clamp(0.3, 2.5));
    notifyListeners();
  }

  double get weatherSpeed => _p.getDouble('weatherSpeed') ?? 1.0;
  set weatherSpeed(double v) {
    _p.setDouble('weatherSpeed', v.clamp(0.3, 2.5));
    notifyListeners();
  }

  // Цвет пузырей: -1 = по теме, иначе ARGB.
  int get msgOutColor => _p.getInt('msgOutColor') ?? -1;
  set msgOutColor(int v) {
    _p.setInt('msgOutColor', v);
    notifyListeners();
  }

  int get msgInColor => _p.getInt('msgInColor') ?? -1;
  set msgInColor(int v) {
    _p.setInt('msgInColor', v);
    notifyListeners();
  }

  // Разблокированы ли admin-настройки (по тапам на версию).
  bool get adminUnlocked => _p.getBool('adminUnlocked') ?? false;
  set adminUnlocked(bool v) {
    _p.setBool('adminUnlocked', v);
    notifyListeners();
  }

  // Включить анимации появления.
  bool get animations => _p.getBool('animations') ?? true;
  set animations(bool v) {
    _p.setBool('animations', v);
    notifyListeners();
  }

  // Стиль анимации появления: 0=fade, 1=подъём, 2=масштаб, 3=подъём+fade.
  int get animStyle => _p.getInt('animStyle') ?? 3;
  set animStyle(int v) {
    _p.setInt('animStyle', v.clamp(0, 3));
    notifyListeners();
  }

  // Скорость анимаций: 0=медленно, 1=обычно, 2=быстро.
  int get animSpeed => _p.getInt('animSpeed') ?? 1;
  set animSpeed(int v) {
    _p.setInt('animSpeed', v.clamp(0, 2));
    notifyListeners();
  }

  int get animDurationMs => switch (animSpeed) {
        0 => 520,
        2 => 180,
        _ => 320,
      };

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
  // Работать в фоне (Android foreground service).
  bool get backgroundReceive => _p.getBool('backgroundReceive') ?? true;
  set backgroundReceive(bool v) {
    _p.setBool('backgroundReceive', v);
    notifyListeners();
  }

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
