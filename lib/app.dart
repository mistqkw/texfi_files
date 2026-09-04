import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_state.dart';
import 'core/settings.dart';
import 'ui/home_page.dart';
import 'ui/onboarding_screen.dart';
import 'ui/pin_lock_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'ui/pixel/pixel_splash.dart';

/// Доступ к AppState из любого места дерева.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope не найден в дереве');
    return scope!.notifier!;
  }
}

class TexfiApp extends StatefulWidget {
  final AppState state;
  const TexfiApp({super.key, required this.state});

  @override
  State<TexfiApp> createState() => _TexfiAppState();
}

class _TexfiAppState extends State<TexfiApp> with WidgetsBindingObserver {
  // Разблокировано на текущий «сеанс» на переднем плане. Сбрасывается, когда
  // приложение уходит в фон, — чтобы при каждом возврате снова спрашивало
  // PIN/отпечаток (иначе висящее в фоне приложение мог открыть кто угодно).
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Перекрываем экран блокировки только при реальном сворачивании
    // (paused/detached), но НЕ во время системного биометрического диалога —
    // он тоже уводит приложение в фон, и иначе отпечаток спрашивался бы
    // дважды по кругу.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final s = widget.state.settings;
      final lockEnabled = s.pinEnabled && s.pinHash != null;
      if (lockEnabled && _unlocked && !PinLockScreen.authenticating) {
        setState(() => _unlocked = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) {
          final s = state.settings;
          final locked = s.pinEnabled && s.pinHash != null && !_unlocked;
          return MaterialApp(
            title: 'TexFi files',
            debugShowCheckedModeBanner: false,
            locale: s.localeCode == 'system' ? null : Locale(s.localeCode),
            supportedLocales: const [
              Locale('en'),
              Locale('ru'),
              Locale('de'),
              Locale('pl'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: s.themeMode,
            theme: _buildTheme(Brightness.light, s),
            darkTheme: _buildTheme(Brightness.dark, s),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(s.uiScale)),
                child: child!,
              );
            },
            home: PixelSplash(
              child: locked
                  ? PinLockScreen(
                      onUnlocked: () => setState(() => _unlocked = true),
                    )
                  : (s.onboardingSeen
                        ? const HomePage()
                        : const OnboardingScreen()),
            ),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness, Settings s) =>
      AppTheme.build(brightness: brightness, sansFamily: _bodyFont(s.fontChoice));

  /// Шрифт основного текста. Пиксельного варианта здесь намеренно нет:
  /// Press Start 2P нечитаем в именах файлов и текстах сообщений.
  static String _bodyFont(int choice) =>
      choice >= 0 && choice < sansFamilyChoices.length
          ? sansFamilyChoices[choice]
          : defaultSansFamily;
}
