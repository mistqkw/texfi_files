import 'package:flutter/material.dart';

/// Единый визуальный словарь пиксель-арт оформления.
///
/// Здесь только токены и примитивы стиля — ни одного виджета с состоянием.
/// Всё остальное (карточки, кнопки, переключатели) строится поверх этих
/// значений, чтобы бордер/тень/скругление нигде не разъезжались.
class PixelTheme {
  PixelTheme._();

  /// Фирменный синий экосистемы TexFi.
  static const Color accent = Color(0xFF4A7DFB);

  /// Приглушённый вариант акцента — для неактивных состояний и обводок,
  /// где полный акцент перетягивает внимание на себя.
  static const Color accentDim = Color(0xFF2E4E9E);

  // Тёмная палитра (основная).
  static const Color darkBg = Color(0xFF0B0B0E);
  static const Color darkSurface = Color(0xFF16161C);
  static const Color darkSurfaceAlt = Color(0xFF1E1E26);
  static const Color darkBorder = Color(0xFF32323E);
  static const Color darkText = Color(0xFFE8E8EF);
  static const Color darkTextDim = Color(0xFF9A9AAB);

  // Светлая палитра. Держим её намеренно «бумажной», а не белоснежной:
  // на чистом белом сплошная офсетная тень выглядит грязным пятном.
  static const Color lightBg = Color(0xFFEDEDF2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF4F4F8);
  static const Color lightBorder = Color(0xFF1A1A22);
  static const Color lightText = Color(0xFF14141A);
  static const Color lightTextDim = Color(0xFF5A5A6B);

  /// Толщина бордера карточек/кнопок. Ровно 2 логических пикселя —
  /// тоньше на плотных экранах теряется, толще выглядит мультяшно.
  static const double border = 2;

  /// Смещение сплошной тени. Без blur — это принципиально: размытая тень
  /// мгновенно ломает пиксельный характер.
  static const double shadow = 4;

  /// Скругление. Максимум 10 — по верхней границе, заданной стилем
  /// экосистемы (8–12), но ближе к квадрату.
  static const double radius = 10;
  static const double radiusSmall = 6;

  /// Семейство пиксельного шрифта. Подключено ассетом, а не через
  /// google_fonts: приложение работает в локальной сети и обязано
  /// выглядеть одинаково без интернета.
  static const String pixelFamily = 'PressStart2P';

  /// Заголовочный (пиксельный) стиль.
  ///
  /// Применяется ТОЛЬКО к заголовкам экранов, заголовкам секций и крупным
  /// акцентным числам/меткам. Имена файлов, тексты сообщений, подписи и
  /// элементы списков этим стилем не набираются — Press Start 2P
  /// нечитаем в длинных строках.
  static TextStyle heading({
    required double size,
    Color? color,
    double height = 1.4,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontFamily: pixelFamily,
      fontSize: size,
      color: color,
      height: height,
      fontWeight: weight,
      // Press Start 2P нарисован моноширинным и уже несёт собственный
      // трекинг; дополнительный letterSpacing разваливает слово.
      letterSpacing: 0,
    );
  }

  /// Мягкая тень-подложка под карточку заданного цвета.
  static List<BoxShadow> shadowFor(Color color, {double offset = shadow}) {
    return [BoxShadow(color: color, offset: Offset(offset, offset))];
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Цвет бордера/тени для текущей темы.
  static Color edge(BuildContext context) => edge2(isDark(context));

  /// То же, но по флагу темы: при сборке ThemeData контекста ещё нет.
  static Color edge2(bool dark) => dark ? darkBorder : lightBorder;
}
