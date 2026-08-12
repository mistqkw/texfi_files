import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_state.dart';
import 'core/settings.dart';
import 'ui/home_page.dart';
import 'ui/onboarding_screen.dart';
import 'ui/pin_lock_screen.dart';

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
                data: mq.copyWith(
                  textScaler: TextScaler.linear(s.uiScale),
                ),
                child: child!,
              );
            },
            home: locked
                ? PinLockScreen(onUnlocked: () => setState(() => _unlocked = true))
                : (s.onboardingSeen
                    ? const HomePage()
                    : const OnboardingScreen()),
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
      visualDensity: d.dense
          ? VisualDensity.compact
          : VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: d.centerTitle,
        elevation: 0,
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
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(d.buttonRadius),
          )),
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
