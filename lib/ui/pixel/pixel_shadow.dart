import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';

/// Ретро-«тень»: не размытие, а тот же прямоугольник, сдвинутый на
/// несколько пикселей вниз-вправо.
///
/// Единственная реализация приёма в приложении — ей пользуются и карточки,
/// и кнопки, и чипы устройств. Отдельный виджет нужен, чтобы «объём»
/// нигде не разъезжался на пиксель.
///
/// [pressed] сдвигает содержимое ровно на высоту тени и укорачивает её:
/// элемент проваливается, как физическая клавиша, а занимаемое место не
/// меняется — соседи не дёргаются.
///
/// Тень рисуется [CustomPaint] позади ребёнка, а не отдельным слоем в
/// [Stack]: со Stack обёртка перестаёт наследовать размер ребёнка и тень
/// растягивается во всю доступную ширину.
class PixelShadowBox extends StatelessWidget {
  const PixelShadowBox({
    super.key,
    required this.child,
    required this.shadowColor,
    this.borderRadius = AppRadius.controlSmallAll,
    this.offset = AppRadius.pixelShadowOffset,
    this.pressed = false,
    this.enabled = true,
  });

  final Widget child;
  final Color shadowColor;
  final BorderRadius borderRadius;
  final double offset;
  final bool pressed;

  /// Выключенный элемент тени не отбрасывает — он «не нажимается».
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Отступ справа и снизу резервирует место под тень: без него элемент
    // занимал бы на offset больше собственной раскладки.
    final body = Padding(
      padding: EdgeInsets.only(right: offset, bottom: offset),
      child: child,
    );

    if (!enabled) return body;

    // Сдвиг содержимого и убыль тени идут от одного значения: кнопка
    // опускается ровно настолько, насколько закрывает собой тень.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: pressed ? 1 : 0),
      duration: AppMotion.instant,
      curve: AppMotion.enter,
      builder: (context, t, child) {
        final shift = offset * t;
        return CustomPaint(
          painter: _PixelShadowPainter(
            color: shadowColor,
            radius: borderRadius,
            offset: offset,
            visible: 1 - t,
          ),
          child: Transform.translate(
            offset: Offset(shift, shift),
            child: child,
          ),
        );
      },
      child: body,
    );
  }
}

class _PixelShadowPainter extends CustomPainter {
  const _PixelShadowPainter({
    required this.color,
    required this.radius,
    required this.offset,
    this.visible = 1,
  });

  final Color color;
  final BorderRadius radius;
  final double offset;

  /// 0..1 — сколько тени осталось видно. Тень не растворяется
  /// прозрачностью, а укорачивается: полупрозрачный блок был бы
  /// единственным местом, где «объём» размывается.
  final double visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (visible <= 0) return;
    final shown = offset * visible;
    final rect = Rect.fromLTWH(
      offset,
      offset,
      size.width - offset - (offset - shown),
      size.height - offset - (offset - shown),
    );
    if (rect.isEmpty) return;
    canvas.drawRRect(radius.toRRect(rect), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PixelShadowPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.offset != offset ||
      old.visible != visible;
}
