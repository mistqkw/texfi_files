import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_state.dart';
import 'core/settings.dart';
import 'ui/home_page.dart';
import 'ui/onboarding_screen.dart';
import 'ui/pin_lock_screen.dart';
import 'ui/terminal.dart';

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

class _TexfiAppState extends State<TexfiApp> {
  // Разблокировано на время текущего запуска приложения.
  bool _unlocked = false;

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
              terminal: s.terminalBubbles,
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
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final surface = isDark && s.pureBlack ? Colors.black : scheme.surface;
    final d = DesignPreset.of(s.designPreset);
    final font = switch (s.fontChoice) {
      1 => 'serif',
      2 => 'monospace',
      _ => 'Roboto',
    };
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(surface: surface),
      scaffoldBackgroundColor: surface,
      fontFamily: font,
      visualDensity: d.dense ? VisualDensity.compact : VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: d.centerTitle,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontFamily: d.titleFont ?? font,
          fontSize: 20,
          fontWeight: d.titleWeight,
        ),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(d.cardRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(d.buttonRadius),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(d.buttonRadius),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(d.fieldRadius),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(d.cardRadius * 0.6),
        ),
      ),
    );
  }
}

/// Параметры дизайн-пресета (скина).
class DesignPreset {
  final String name;
  final double cardRadius;
  final double buttonRadius;
  final double fieldRadius;
  final bool centerTitle;
  final FontWeight titleWeight;
  final bool dense;
  final String? titleFont; // null = как общий шрифт

  const DesignPreset({
    required this.name,
    required this.cardRadius,
    required this.buttonRadius,
    required this.fieldRadius,
    required this.centerTitle,
    required this.titleWeight,
    required this.dense,
    this.titleFont,
  });

  // Фирменный стиль: чёткие скруглённые «плашки», плотный sans-заголовок.
  static const texfi = DesignPreset(
    name: 'TexFi',
    cardRadius: 22,
    buttonRadius: 18,
    fieldRadius: 18,
    centerTitle: false,
    titleWeight: FontWeight.w800,
    dense: false,
  );

  static const material = DesignPreset(
    name: 'Material',
    cardRadius: 20,
    buttonRadius: 16,
    fieldRadius: 18,
    centerTitle: false,
    titleWeight: FontWeight.w700,
    dense: false,
  );
  static const apple = DesignPreset(
    name: 'Apple',
    cardRadius: 22,
    buttonRadius: 22,
    fieldRadius: 22,
    centerTitle: true,
    titleWeight: FontWeight.w600,
    dense: false,
  );
  static const samsung = DesignPreset(
    name: 'Samsung',
    cardRadius: 28,
    buttonRadius: 26,
    fieldRadius: 26,
    centerTitle: false,
    titleWeight: FontWeight.w800,
    dense: false,
  );
  static const windows = DesignPreset(
    name: 'Windows',
    cardRadius: 8,
    buttonRadius: 6,
    fieldRadius: 6,
    centerTitle: false,
    titleWeight: FontWeight.w600,
    dense: true,
  );

  static DesignPreset of(int i) => switch (i) {
    1 => material,
    2 => apple,
    3 => samsung,
    4 => windows,
    _ => texfi,
  };

  static const all = [texfi, material, apple, samsung, windows];
}

/// Экран запуска. В терминальном режиме — чёрный фон, лого проступает
/// сквозь свечение, снизу печатается строка `❯ texfi files_` посимвольно
/// с мигающим курсором. Иначе — прежний вариант с масштабом и радиальным
/// градиентом под тему.
class _Splash extends StatefulWidget {
  final Widget child;
  final bool terminal;
  const _Splash({required this.child, required this.terminal});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  static const _bootText = '❯ texfi files';
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.terminal ? 1500 : 700),
  )..forward();
  late final AnimationController _cursor = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration(milliseconds: widget.terminal ? 1750 : 950),
      () {
        if (mounted) setState(() => _done = true);
      },
    );
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
        duration: const Duration(milliseconds: 220),
        child: widget.child,
      );
    }
    return widget.terminal ? _terminalSplash(context) : _classicSplash(context);
  }

  Widget _terminalSplash(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Лого проступает первым (0–45%), строка загрузки печатается следом
    // (35–90%), курсор мигает независимо всё время.
    final logoFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    final typeCurve = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.35, 0.9, curve: Curves.easeIn),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [
                  cs.primary.withValues(alpha: 0.22),
                  Colors.black,
                ],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: logoFade,
                child: ScaleTransition(
                  scale: Tween(
                    begin: 0.8,
                    end: 1.0,
                  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
                  child: Image.asset(
                    'assets/brand/mark-white.png',
                    width: 88,
                    height: 88,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.bookmark_rounded,
                      size: 88,
                      color: cs.primary,
                    ),
                  ),
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
                            color: cursorOn
                                ? cs.primary
                                : Colors.transparent,
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
        ],
      ),
    );
  }

  Widget _classicSplash(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scaleCurve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    final fadeCurve = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.55),
    );
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [
                  cs.primary.withValues(alpha: dark ? 0.16 : 0.08),
                  cs.surface,
                ],
              ),
            ),
          ),
          FadeTransition(
            opacity: fadeCurve,
            child: ScaleTransition(
              scale: Tween(begin: 0.72, end: 1.0).animate(scaleCurve),
              child: Image.asset(
                dark ? 'assets/brand/mark-white.png' : 'assets/brand/mark.png',
                width: 96,
                height: 96,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.bookmark_rounded, size: 96, color: cs.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
