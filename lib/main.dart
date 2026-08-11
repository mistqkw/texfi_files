import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';
import 'app_state.dart';
import 'core/auth_service.dart';
import 'core/settings.dart';
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

  runApp(TexfiApp(state: state));
}
