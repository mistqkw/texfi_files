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

  // Шрифт: 0=обычный, 2=моноширинный.
  int get fontChoice => _p.getInt('fontChoice') ?? 0;
  set fontChoice(int v) {
    _p.setInt('fontChoice', v.clamp(0, 2));
    notifyListeners();
  }

  // Компактная плотность (меньше отступы).
  bool get compact => _p.getBool('compact') ?? false;
  set compact(bool v) {
    _p.setBool('compact', v);
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

  // Яркость обводки блоков 0.06..1.0.
  double get borderOpacity => _p.getDouble('borderOpacity') ?? 0.55;
  set borderOpacity(double v) {
    _p.setDouble('borderOpacity', v.clamp(0.06, 1.0));
    notifyListeners();
  }

  // Что показывать во врезке рамки.
  bool get prefixDevice => _p.getBool('prefixDevice') ?? true;
  set prefixDevice(bool v) {
    _p.setBool('prefixDevice', v);
    notifyListeners();
  }

  bool get prefixType => _p.getBool('prefixType') ?? true;
  set prefixType(bool v) {
    _p.setBool('prefixType', v);
    notifyListeners();
  }

  bool get prefixSize => _p.getBool('prefixSize') ?? false;
  set prefixSize(bool v) {
    _p.setBool('prefixSize', v);
    notifyListeners();
  }

  bool get prefixTime => _p.getBool('prefixTime') ?? false;
  set prefixTime(bool v) {
    _p.setBool('prefixTime', v);
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

  // --- Файлы и синхронизация ---
  // Маршрутизация: 0=авто (по размеру), 1=всегда облако (если влезает), 2=только P2P (никогда не в облако).
  int get cloudMode => _p.getInt('cloudMode') ?? 0;
  set cloudMode(int v) {
    _p.setInt('cloudMode', v.clamp(0, 2));
    notifyListeners();
  }

  // Избирательная синхронизация: не тянуть медиа из облака автоматически.
  bool get selectiveSync => _p.getBool('selectiveSync') ?? false;
  set selectiveSync(bool v) {
    _p.setBool('selectiveSync', v);
    notifyListeners();
  }

  // --- Безопасность ---
  // Шифровать файлы перед загрузкой в облако (AES-GCM, ключ хранится локально).
  bool get encryptCloud => _p.getBool('encryptCloud') ?? false;
  set encryptCloud(bool v) {
    _p.setBool('encryptCloud', v);
    notifyListeners();
  }

  bool get pinEnabled => _p.getBool('pinEnabled') ?? false;
  set pinEnabled(bool v) {
    _p.setBool('pinEnabled', v);
    notifyListeners();
  }

  String? get pinHash => _p.getString('pinHash');
  set pinHash(String? v) {
    if (v == null) {
      _p.remove('pinHash');
    } else {
      _p.setString('pinHash', v);
    }
    notifyListeners();
  }

  bool get biometricEnabled => _p.getBool('biometricEnabled') ?? false;
  set biometricEnabled(bool v) {
    _p.setBool('biometricEnabled', v);
    notifyListeners();
  }
}
