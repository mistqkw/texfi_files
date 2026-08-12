import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';
import 'app_state.dart';
import 'core/auth_service.dart';
import 'core/background.dart';
import 'core/quick_share.dart';
import 'core/settings.dart';
import 'l10n/app_strings.dart';
import 'store/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final settings = await Settings.load();
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

  runApp(TexfiApp(state: state));
}
