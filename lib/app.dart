import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_state.dart';
import 'core/settings.dart';
import 'ui/home_page.dart';
import 'ui/onboarding_screen.dart';
import 'ui/pin_lock_screen.dart';
import 'ui/terminal.dart';
import 'ui/pixel/pixel_icons.dart';
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
          final seed = Color(s.seedColor);
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
            theme: _buildTheme(seed, Brightness.light, s),
            darkTheme: _buildTheme(seed, Brightness.dark, s),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(s.uiScale)),
                child: child!,
              );
            },
            home: _Splash(
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

  ThemeData _buildTheme(Color seed, Brightness brightness, Settings s) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ).copyWith(
            surface: s.pureBlack ? Colors.black : PixelTheme.surface,
            onSurface: PixelTheme.textPrimary,
            onSurfaceVariant: PixelTheme.textMuted,
            outlineVariant: PixelTheme.border,
            error: PixelTheme.danger,
          )
        : ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    final surface = scheme.surface;
    final font = s.fontChoice == 2 ? 'monospace' : 'Roboto';
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: font,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: PixelTheme.fontFamily,
          color: scheme.onSurface,
          fontSize: 13,
        ),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: PixelTheme.cardRadiusAll,
          side: BorderSide(color: scheme.outlineVariant, width: PixelTheme.borderWidth),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: PixelTheme.controlRadiusAll),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: PixelTheme.controlRadiusAll),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: PixelTheme.controlRadiusAll,
          borderSide: BorderSide.none,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: PixelTheme.controlRadiusAll),
        side: BorderSide(color: scheme.outlineVariant, width: PixelTheme.borderWidth),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(scheme.outlineVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: PixelTheme.controlRadiusAll),
      ),
    );
  }
}

/// Экран запуска: чёрный фон, лого пиксельно проступает, снизу печатается
/// строка `❯ texfi files_` посимвольно с мигающим курсором. Быстрый,
/// не более 1.7с — не должен ощущаться как задержка.
class _Splash extends StatefulWidget {
  final Widget child;
  const _Splash({required this.child});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  static const _bootText = '❯ texfi files';
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();
  late final AnimationController _cursor = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1450), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
      );
    }
    final cs = Theme.of(context).colorScheme;
    // Лого проступает построчно снизу вверх (0–50%), строка загрузки
    // печатается следом (40–90%), курсор мигает независимо всё время.
    final revealCurve = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );
    final typeCurve = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.4, 0.9, curve: Curves.easeIn),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: revealCurve,
              builder: (context, _) => ClipRect(
                clipper: _BottomUpClipper(revealCurve.value),
                child: PixelIcon('transfer', size: 88, color: PixelTheme.accent),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: Listenable.merge([_c, _cursor]),
              builder: (context, _) {
                final n = (typeCurve.value * _bootText.length)
                    .floor()
                    .clamp(0, _bootText.length);
                final shown = _bootText.substring(0, n);
                final cursorOn = _cursor.value > 0.5;
                return Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: shown,
                        style: monoStyle(color: cs.primary, size: 16),
                      ),
                      TextSpan(
                        text: '_',
                        style: monoStyle(
                          color: cursorOn ? cs.primary : Colors.transparent,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Открывает нижнюю часть ребёнка по мере роста [progress] 0..1 — построчная
/// пиксельная отрисовка снизу вверх.
class _BottomUpClipper extends CustomClipper<Rect> {
  final double progress;
  const _BottomUpClipper(this.progress);

  @override
  Rect getClip(Size size) {
    final top = size.height * (1 - progress);
    return Rect.fromLTWH(0, top, size.width, size.height - top);
  }

  @override
  bool shouldReclip(covariant _BottomUpClipper old) => old.progress != progress;
}
