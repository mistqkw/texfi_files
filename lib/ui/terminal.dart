import 'dart:ui' show ClipOp;

import 'package:flutter/material.dart';
import 'pixel/pixel_theme.dart';

/// Пиксель-карточка TexFi: чёрный фон, 2px квадратная обводка, сплошная
/// офсетная тень (без blur), врезанная в верхнюю линию подпись вида
/// `❯ phone · txt`. Общий примитив для всех карточек/пузырей приложения.

/// Моноширинный стиль для служебных надписей (префиксы, время, метрики).
/// Основной текст сообщений остаётся обычным шрифтом — так читаемее.
const List<String> kMonoFallback = [
  'JetBrains Mono',
  'Fira Code',
  'DejaVu Sans Mono',
  'Roboto Mono',
  'monospace',
  'Courier New',
];

TextStyle monoStyle({
  required Color color,
  double size = 11,
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0.2,
}) =>
    TextStyle(
      fontFamilyFallback: kMonoFallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: 1.2,
    );


/// Рамка с разрывом под врезанную подпись.
class _TerminalBorderPainter extends CustomPainter {
  final Rect? gap;
  final Color color;
  final double radius;
  final double stroke;

  const _TerminalBorderPainter({
    required this.gap,
    required this.color,
    required this.radius,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    final half = stroke / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(half, half, size.width - stroke, size.height - stroke),
      Radius.circular(radius),
    );
    canvas.save();
    if (gap != null) {
      // Вырезаем область подписи, чтобы линия её не пересекала.
      canvas.clipRect(gap!, clipOp: ClipOp.difference);
    }
    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TerminalBorderPainter old) =>
      old.gap != gap ||
      old.color != color ||
      old.radius != radius ||
      old.stroke != stroke;
}

/// Блок в терминальном стиле: тонкая рамка, микро-скругление,
/// подпись, врезанная в верхнюю линию.
class TerminalBox extends StatelessWidget {
  /// Текст врезки без символа-промпта (он добавляется автоматически).
  final String? label;

  /// Показывать ли символ ❯ перед подписью.
  final bool prompt;

  /// Цвет обводки.
  final Color borderColor;

  /// Цвет подписи (обычно акцент для своих, приглушённый для входящих).
  final Color labelColor;

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double stroke;

  /// Необязательная заливка (по умолчанию прозрачная — виден обой).
  final Color? fill;

  const TerminalBox({
    super.key,
    this.label,
    this.prompt = true,
    required this.borderColor,
    required this.labelColor,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 10),
    this.radius = PixelTheme.cardRadius,
    this.stroke = PixelTheme.borderWidth,
    this.fill,
  });

  static const double _labelLeft = 12;
  static const double _labelPadH = 5;

  @override
  Widget build(BuildContext context) {
    final text = label;
    final style = monoStyle(color: labelColor);

    if (text == null || text.isEmpty) {
      return _painted(gap: null, child: child);
    }

    final full = prompt ? '❯ $text' : text;
    final tp = TextPainter(
      text: TextSpan(text: full, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();

    final labelH = tp.height;
    final gap = Rect.fromLTWH(
      _labelLeft - _labelPadH,
      -labelH / 2,
      tp.width + _labelPadH * 2,
      labelH,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(top: labelH / 2),
          child: _painted(gap: gap, child: child),
        ),
        Positioned(
          // Смещаем на подложку, чтобы сам текст начинался ровно на _labelLeft.
          left: _labelLeft - _labelPadH,
          top: 0,
          child: _label(full, style),
        ),
      ],
    );
  }

  /// Врезка: символ-промпт красится акцентом, остальное — приглушённо.
  /// Подложка чёрная — врезка нависает над верхней линией и иначе читалась
  /// бы поверх обоев.
  Widget _label(String full, TextStyle style) {
    final Widget text = prompt
        ? Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '❯ ', style: style.copyWith(color: labelColor)),
                TextSpan(
                  text: full.substring(2),
                  style:
                      style.copyWith(color: labelColor.withValues(alpha: 0.72)),
                ),
              ],
            ),
            maxLines: 1,
          )
        : Text(full, style: style, maxLines: 1);
    return ColoredBox(
      color: fill ?? Colors.black,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _labelPadH),
        child: text,
      ),
    );
  }

  Widget _painted({required Rect? gap, required Widget child}) {
    // По умолчанию блок полностью чёрный (OLED), обои остаются только вокруг.
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: fill ?? Colors.black,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: PixelTheme.hardShadow(),
      ),
      child: Padding(padding: padding, child: child),
    );
    return CustomPaint(
      painter: _TerminalBorderPainter(
        gap: gap,
        color: borderColor,
        radius: radius,
        stroke: stroke,
      ),
      child: content,
    );
  }
}

/// Разделитель даты: тонкая линия через всю ширину с текстом посередине.
class TerminalDivider extends StatelessWidget {
  final String text;
  const TerminalDivider({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final line = cs.outlineVariant.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: line, height: 1, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text.toUpperCase(),
              style: monoStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                size: 10,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Expanded(child: Divider(color: line, height: 1, thickness: 1)),
        ],
      ),
    );
  }
}
