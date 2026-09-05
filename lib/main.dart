import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app.dart';
import 'app_state.dart';
import 'core/audio_handler.dart';
import 'core/auth_service.dart';
import 'core/background.dart';
import 'core/haptics.dart';
import 'core/linux/mpris_service.dart';
import 'core/quick_share.dart';
import 'core/settings.dart';
import 'l10n/app_strings.dart';
import 'store/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Edge-to-edge: без этого на Android системная строка статуса рисуется
  // непрозрачной ПОВЕРХ капсулы шапки, и вместе они визуально сливаются в
  // одну толстую полосу — на десктопе такой строки нет, поэтому там капсула
  // сама по себе смотрелась компактно. Цвет/яркость иконок статус-бара —
  // реактивно, в home_page.dart (там известна текущая тема).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final settings = await Settings.load();

  // Возможности вибромотора опрашиваются один раз при старте: делать это
  // при первом же нажатии значило бы, что первый отклик приходит с
  // задержкой на асинхронный опрос платформы.
  Haptics.enabled = settings.hapticsEnabled;
  await Haptics.init();
  final store = Store();
  await store.init();
  final auth = await AuthService.load();

  final state = AppState(settings, store, auth);
  await state.startNetwork();

  // Фоновый приём на Android — foreground service.
  if (Platform.isAndroid && settings.backgroundReceive) {
    final t = AppStrings(settings.effectiveLanguageCode);
    await Background.start(t.bgTitle, t.bgText);
  }

  // «Поделиться в TexFi files» из других приложений (Android/iOS).
  if (QuickShare.supported) {
    await QuickShare(store, settings).start();
  }

  // Медиа-уведомление в шторке/на экране блокировки — только Android
  // (audio_service поддерживает iOS/desktop, но здесь их пока нет).
  if (Platform.isAndroid) {
    // Без POST_NOTIFICATIONS (Android 13+) система молча не покажет вообще
    // никаких уведомлений — в том числе медиа-уведомление плеера. Запрос
    // в Background.start() срабатывает, только если включён фоновый приём;
    // здесь просим разрешение безусловно, раз оно нужно и плееру тоже.
    // На этом шаге (до runApp/до полного attach активности) запрос может
    // тихо не сработать на некоторых прошивках — оборачиваем в try, а
    // повторный запрос с гарантированно готовым контекстом делаем ещё раз
    // из HomePage (см. home_page.dart, initState).
    try {
      Background.init();
      // permission_handler надёжнее показывает системный диалог
      // POST_NOTIFICATIONS, чем внутренний запрос плагина; без этого
      // разрешения Android 13+ молча прячет ЛЮБЫЕ уведомления, включая
      // медиа-уведомление плеера в шторке.
      final st = await Permission.notification.status;
      if (st.isDenied) await Permission.notification.request();
    } catch (_) {
      // Не критично — повторим из HomePage.
    }
    await AudioService.init(
      builder: () => TexFiAudioHandler(state.player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'app.texfi.texfi_files.audio',
        androidNotificationChannelName: 'TexFi files playback',
        // Монохромная small-icon (см. res/drawable/ic_stat_music.xml) —
        // цветной ic_launcher как small-icon на части прошивок ломает показ.
        androidNotificationIcon: 'drawable/ic_stat_music',
        // false — уведомление не «прилипшее»: остаётся видимым и на паузе,
        // и его можно смахнуть, когда музыка не играет.
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
    );
  }

  // Тот же мост между плеером и системой, что AudioService даёт Android —
  // здесь через MPRIS: медиа-клавиши, GNOME Shell/KDE Plasma, playerctl.
  // tryStart сам решает, что делать на не-Linux и на машине без session
  // bus — ошибка там не должна ронять остальное приложение.
  await MprisService.tryStart(state.player);

  runApp(TexfiApp(state: state));
}
