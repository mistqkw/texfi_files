import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_state.dart';
import 'core/settings.dart';
import 'ui/home_page.dart';
import 'ui/onboarding_screen.dart';
import 'ui/pin_lock_screen.dart';
import 'ui/pixel/pixel_splash.dart';
import 'ui/pixel/pixel_theme.dart';

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

  /// Тема строится вокруг пиксельного словаря, а не вокруг ColorScheme
  /// из seed-цвета: карточки и кнопки рисуют бордер и тень сами, поэтому
  /// материаловские elevation/surfaceTint здесь только мешают — их
  /// приходится гасить в каждом компоненте.
  ThemeData _buildTheme(Brightness brightness, Settings s) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? PixelTheme.darkBg : PixelTheme.lightBg;
    final surface = dark ? PixelTheme.darkSurface : PixelTheme.lightSurface;
    final fg = dark ? PixelTheme.darkText : PixelTheme.lightText;
    final dim = dark ? PixelTheme.darkTextDim : PixelTheme.lightTextDim;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: PixelTheme.accent,
      onPrimary: Colors.white,
      secondary: PixelTheme.accent,
      onSecondary: Colors.white,
      error: const Color(0xFFE5484D),
      onError: Colors.white,
      surface: surface,
      onSurface: fg,
      onSurfaceVariant: dim,
      outline: PixelTheme.edge2(dark),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      // Читаемый текст набирается обычным шрифтом. Пиксельный подключается
      // точечно через PixelTheme.heading — заголовки и акцентные метки.
      fontFamily: _bodyFont(s.fontChoice),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: fg),
        titleTextStyle: PixelTheme.heading(size: 12, color: fg),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PixelTheme.radius),
          side: BorderSide(color: PixelTheme.edge2(dark), width: PixelTheme.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PixelTheme.radius),
          side: BorderSide(color: PixelTheme.edge2(dark), width: PixelTheme.border),
        ),
        titleTextStyle: PixelTheme.heading(size: 11, color: fg),
        contentTextStyle: TextStyle(fontSize: 14, color: fg, height: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? PixelTheme.darkSurfaceAlt : PixelTheme.lightSurfaceAlt,
        hintStyle: TextStyle(color: dim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PixelTheme.radiusSmall),
          borderSide: BorderSide(color: PixelTheme.edge2(dark), width: PixelTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PixelTheme.radiusSmall),
          borderSide: BorderSide(color: PixelTheme.edge2(dark), width: PixelTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PixelTheme.radiusSmall),
          borderSide: const BorderSide(color: PixelTheme.accent, width: PixelTheme.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? PixelTheme.darkSurfaceAlt : PixelTheme.lightText,
        contentTextStyle: TextStyle(
          color: dark ? PixelTheme.darkText : Colors.white,
          fontSize: 13.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PixelTheme.radiusSmall),
          side: BorderSide(color: PixelTheme.accent, width: PixelTheme.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: PixelTheme.edge2(dark),
        thickness: PixelTheme.border,
        space: PixelTheme.border,
      ),
    );
  }

  /// Шрифт основного текста. Пиксельного варианта здесь намеренно нет:
  /// Press Start 2P нечитаем в именах файлов и текстах сообщений.
  static String _bodyFont(int choice) => switch (choice) {
    1 => 'Manrope',
    2 => 'monospace',
    _ => 'Roboto',
  };
}
