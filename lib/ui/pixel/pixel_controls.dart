import 'package:flutter/material.dart';
import 'pixel_theme.dart';

/// Пиксельные чекбокс/переключатель/радио — квадратные, с 2px обводкой,
/// вместо стандартных Material-виджетов.

class PixelCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  const PixelCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value ? cs.primary : Colors.transparent,
          borderRadius: PixelTheme.controlRadiusAll,
          border: Border.all(
            color: value ? cs.primary : cs.outlineVariant,
            width: PixelTheme.borderWidth,
          ),
        ),
        child: value
            ? CustomPaint(painter: _CheckPainter(cs.onPrimary))
            : null,
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final Color color;
  _CheckPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.14
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.8, size.height * 0.28);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.color != color;
}

/// Квадратный переключатель: два состояния, ползунок-квадрат внутри рамки.
class PixelSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const PixelSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const w = 40.0, h = 22.0, knob = 16.0, pad = 3.0;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: value ? cs.primary.withValues(alpha: 0.28) : Colors.transparent,
          borderRadius: PixelTheme.controlRadiusAll,
          border: Border.all(
            color: value ? cs.primary : cs.outlineVariant,
            width: PixelTheme.borderWidth,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: pad),
            child: Container(
              width: knob,
              height: knob,
              color: value ? cs.primary : cs.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Квадратный радио-индикатор.
class PixelRadio<T> extends StatelessWidget {
  final T value;
  final T groupValue;
  final ValueChanged<T>? onChanged;
  const PixelRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = value == groupValue;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(value),
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: PixelTheme.borderWidth,
          ),
        ),
        child: selected
            ? Container(width: 10, height: 10, color: cs.primary)
            : null,
      ),
    );
  }
}

/// Пиксельный аватар: квадратная рамка с засечками по углам вместо гладкого
/// круга. Содержимое (инициалы/иконка/картинка) остаётся настраиваемым.
class PixelAvatar extends StatelessWidget {
  final Widget? child;
  final ImageProvider? image;
  final Color? background;
  final Color? borderColor;
  final double size;

  const PixelAvatar({
    super.key,
    this.child,
    this.image,
    this.background,
    this.borderColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? cs.primaryContainer,
        image: image != null ? DecorationImage(image: image!, fit: BoxFit.cover) : null,
        border: Border.all(
          color: borderColor ?? cs.primary,
          width: PixelTheme.borderWidth,
        ),
      ),
      child: image != null
          ? null
          : DefaultTextStyle.merge(
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
              child: child ?? const SizedBox.shrink(),
            ),
    );
  }
}

/// Карточка пиксель-арт языка: умеренно скруглена (10), 2px обводка,
/// сплошная офсетная тень (без blur). Универсальная замена Material Card
/// в местах, где не нужна врезанная подпись TerminalBox.
class PixelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? fill;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool raised;

  const PixelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.fill,
    this.borderColor,
    this.onTap,
    this.raised = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill ?? cs.surface,
        borderRadius: PixelTheme.cardRadiusAll,
        border: Border.all(
          color: borderColor ?? cs.outlineVariant,
          width: PixelTheme.borderWidth,
        ),
        boxShadow: raised ? PixelTheme.hardShadow() : null,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: PixelTheme.cardRadiusAll,
        child: content,
      );
    }
    return Padding(padding: margin ?? EdgeInsets.zero, child: content);
  }
}

/// Кнопка пиксель-арт языка: почти квадратная (2px радиус), с офсетной
/// тенью.
class PixelButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const PixelButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = color ?? cs.primary;
    return InkWell(
      onTap: onPressed,
      borderRadius: PixelTheme.controlRadiusAll,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: onPressed == null ? bg.withValues(alpha: 0.4) : bg,
          borderRadius: PixelTheme.controlRadiusAll,
          border: Border.all(color: Colors.black, width: PixelTheme.borderWidth),
          boxShadow: PixelTheme.hardShadow(
            offset: const Offset(PixelTheme.shadowOffset, PixelTheme.shadowOffset),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w700),
          child: child,
        ),
      ),
    );
  }
}
