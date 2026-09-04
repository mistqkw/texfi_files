import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Глобальные настройки приложения.
///
/// Набор намеренно небольшой: всё, что было чистой косметикой (скины,
/// пресеты палитр, погодные эффекты, цвета пузырей, стили и скорость
/// анимаций), убрано в пользу одного визуального языка. Осталось то, что
/// либо меняет поведение, либо нужно для доступности.
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
    // Обои по умолчанию больше не подставляются: фон приложения — ровный
    // тёмный, а фото остаётся сознательным выбором пользователя.
    await _migrate(p);
    return s;
  }

  /// Ключи настроек, которых больше нет.
  ///
  /// Читать их всё равно никто не будет — каждый геттер подставляет
  /// значение по умолчанию при отсутствующем ключе, — но чистим, чтобы
  /// хранилище не таскало за собой мусор от версии к версии и чтобы
  /// повторное появление настройки с тем же именем не подхватило чужое
  /// старое значение.
  static const _obsoleteKeys = [
    'designPreset', 'themePreset', 'bubbleStyle', 'bubbleRadius', 'compact',
    'terminalBubbles', 'borderOpacity', 'seedColor', 'pureBlack',
    'chatBackground', 'bgEffect', 'gradientBg',
    'weatherSize', 'weatherDensity', 'weatherSpeed',
    'msgOutColor', 'msgInColor',
    'prefixDevice', 'prefixType', 'prefixSize', 'prefixTime',
    'animStyle', 'animSpeed', 'wallpaperSeeded',
  ];

  static Future<void> _migrate(SharedPreferences p) async {
    for (final key in _obsoleteKeys) {
      if (p.containsKey(key)) await p.remove(key);
    }
    // Фото-фон мог указывать на файл, которого уже нет: удалённая
    // картинка, переустановка, вычищенный кеш. Без этой проверки экран
    // уходил в бесконечный поток ошибок декодирования на каждом кадре.
    final bg = p.getString('chatBgImage');
    if (bg != null && !File(bg).existsSync()) {
      await p.remove('chatBgImage');
    }
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

  double get uiScale => _p.getDouble('uiScale') ?? 1.0;
  set uiScale(double v) {
    _p.setDouble('uiScale', v.clamp(0.8, 1.4));
    notifyListeners();
  }

  // Шрифт: 0=обычный, 1=с засечками, 2=моноширинный.
  int get fontChoice => _p.getInt('fontChoice') ?? 0;
  set fontChoice(int v) {
    _p.setInt('fontChoice', v.clamp(0, 2));
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

  // Разблокированы ли admin-настройки (по тапам на версию).
  bool get adminUnlocked => _p.getBool('adminUnlocked') ?? false;
  set adminUnlocked(bool v) {
    _p.setBool('adminUnlocked', v);
    notifyListeners();
  }

  // Тактильный отклик. Единый выключатель для всего приложения — как в
  // f0kus, чтобы настройка вела себя одинаково во всей экосистеме.
  bool get hapticsEnabled => _p.getBool('hapticsEnabled') ?? true;
  set hapticsEnabled(bool v) {
    _p.setBool('hapticsEnabled', v);
    notifyListeners();
  }

  // --- Фон ленты ---
  // Затемнение фото-фона 0..0.8.
  double get bgDim => _p.getDouble('bgDim') ?? 0.45;
  set bgDim(double v) {
    _p.setDouble('bgDim', v.clamp(0, 0.8));
    notifyListeners();
  }

  // Размытие фото-фона в логических пикселях, 0..24. 0 = без размытия.
  double get bgBlur => _p.getDouble('bgBlur') ?? 0;
  set bgBlur(double v) {
    _p.setDouble('bgBlur', v.clamp(0, 24));
    notifyListeners();
  }

  // Снегопад поверх фона.
  bool get snow => _p.getBool('snow') ?? false;
  set snow(bool v) {
    _p.setBool('snow', v);
    notifyListeners();
  }

  // Скорость снега: 0 = медленно, 1 = средне, 2 = быстро.
  int get snowSpeed => _p.getInt('snowSpeed') ?? 1;
  set snowSpeed(int v) {
    _p.setInt('snowSpeed', v.clamp(0, 2));
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
