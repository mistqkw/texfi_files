import 'package:flutter/material.dart';

/// Дизайн-токены пиксель-арт языка экосистемы TexFi — значения совпадают
/// с палитрой TexFi f0kus/m0ney (тёмная тема: чёрный/тёмно-серый фон,
/// фирменный синий акцент). Карточки — умеренно скруглены (8-12), кнопки/
/// переключатели/поля — почти квадратные (0-4), с 2px обводкой и сплошной
/// офсетной тенью без blur. Пиксельный шрифт — только для заголовков
/// экранов/секций и крупных чисел, не для основного текста.
class PixelTheme {
  PixelTheme._();

  static const Color accent = Color(0xFF4A7DFB);
  static const Color accentDeep = Color(0xFF2B4FB0);
  static const Color bg = Color(0xFF0B0B0E);
  static const Color surface = Color(0xFF15151A);
  static const Color surfaceRaised = Color(0xFF1F1F26);
  static const Color border = Color(0xFF2C2C35);
  static const Color textPrimary = Color(0xFFF2F3F7);
  static const Color textMuted = Color(0xFF9A9AA8);
  static const Color textFaint = Color(0xFF5C5C68);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF3ED598);
  static const Color warning = Color(0xFFFFB648);

  static const double borderWidth = 2;
  static const double cardRadius = 10;
  static const double controlRadius = 2;
  static const double shadowOffset = 3;

  static const BorderRadius cardRadiusAll =
      BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius controlRadiusAll =
      BorderRadius.all(Radius.circular(controlRadius));

  /// Сплошная (без blur) офсетная тень для пиксель-карточек/кнопок.
  static List<BoxShadow> hardShadow({Color? color, Offset? offset}) => [
        BoxShadow(
          color: color ?? Colors.black.withValues(alpha: 0.55),
          offset: offset ?? const Offset(shadowOffset, shadowOffset),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ];

  static const String fontFamily = 'PressStart2P';

  static TextStyle heading({
    double size = 14,
    Color color = textPrimary,
    double height = 1.4,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        color: color,
        height: height,
      );

  static TextStyle number({
    double size = 22,
    Color color = textPrimary,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        color: color,
        height: 1.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Заголовок экрана/секции в пиксельном шрифте — обёртка для единообразия.
class PixelHeading extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PixelHeading(
    this.text, {
    super.key,
    this.size = 14,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: PixelTheme.heading(size: size, color: color ?? cs.onSurface),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
