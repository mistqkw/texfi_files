import 'package:flutter/material.dart';
import 'app_state.dart';
import 'core/settings.dart';
import 'ui/home_page.dart';

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

class TexfiApp extends StatelessWidget {
  final AppState state;
  const TexfiApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) {
          final s = state.settings;
          final seed = Color(s.seedColor);
          return MaterialApp(
            title: 'TexFi files',
            debugShowCheckedModeBanner: false,
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
            home: const HomePage(),
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
          fontFamily: font,
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

  const DesignPreset({
    required this.name,
    required this.cardRadius,
    required this.buttonRadius,
    required this.fieldRadius,
    required this.centerTitle,
    required this.titleWeight,
    required this.dense,
  });

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
        1 => apple,
        2 => samsung,
        3 => windows,
        _ => material,
      };

  static const all = [material, apple, samsung, windows];
}
