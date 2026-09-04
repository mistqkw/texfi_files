import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pixel_theme.dart';
import 'pixel_icons.dart';

/// Базовая карточка: 2px бордер + сплошная офсетная тень без размытия.
class PixelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final double shadowOffset;
  final VoidCallback? onTap;

  const PixelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borderColor,
    this.radius = PixelTheme.radius,
    this.shadowOffset = PixelTheme.shadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = PixelTheme.isDark(context);
    final surface =
        color ?? (dark ? PixelTheme.darkSurface : PixelTheme.lightSurface);
    final edge = borderColor ?? PixelTheme.edge(context);
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: edge, width: PixelTheme.border),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: PixelTheme.shadowFor(edge, offset: shadowOffset),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return _PressSink(onTap: onTap!, offset: shadowOffset, child: body);
  }
}

/// Нажатие «утапливает» элемент в собственную тень: содержимое сдвигается на
/// величину офсета, тень при этом схлопывается. Тот же приём, что в f0kus —
/// даёт физический отклик без единой плавной кривой.
class _PressSink extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double offset;

  const _PressSink({
    required this.child,
    required this.onTap,
    required this.offset,
  });

  @override
  State<_PressSink> createState() => _PressSinkState();
}

class _PressSinkState extends State<_PressSink> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          _down ? widget.offset : 0,
          _down ? widget.offset : 0,
          0,
        ),
        child: _down
            // Пока элемент утоплен, тень убираем — иначе он «висит» над
            // собственной тенью и эффект вдавливания не читается.
            ? _NoShadow(child: widget.child)
            : widget.child,
      ),
    );
  }
}

/// Снимает boxShadow у вложенного Container'а на время нажатия.
class _NoShadow extends StatelessWidget {
  final Widget child;
  const _NoShadow({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = child;
    if (c is Container && c.decoration is BoxDecoration) {
      final d = c.decoration as BoxDecoration;
      return Container(
        padding: c.padding,
        decoration: d.copyWith(boxShadow: const []),
        child: c.child,
      );
    }
    return child;
  }
}

/// Основная кнопка. Заголовочный (пиксельный) шрифт здесь уместен — это
/// короткая акцентная метка, а не текст для чтения.
class PixelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final bool primary;
  final bool expand;
  final double fontSize;

  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.expand = false,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    final dark = PixelTheme.isDark(context);
    final enabled = onPressed != null;
    final bg = primary
        ? (enabled ? PixelTheme.accent : PixelTheme.accentDim)
        : (dark ? PixelTheme.darkSurfaceAlt : PixelTheme.lightSurfaceAlt);
    final fg = primary
        ? Colors.white
        : (dark ? PixelTheme.darkText : PixelTheme.lightText);
    final edge = primary
        ? (dark ? PixelTheme.darkBorder : PixelTheme.lightBorder)
        : PixelTheme.edge(context);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          PixelIcon(icon!, size: fontSize + 6, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: PixelTheme.heading(
              size: fontSize,
              color: enabled ? fg : fg.withValues(alpha: 0.45),
              height: 1.3,
            ),
          ),
        ),
      ],
    );

    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: enabled ? bg : bg.withValues(alpha: 0.5),
        border: Border.all(color: edge, width: PixelTheme.border),
        borderRadius: BorderRadius.circular(PixelTheme.radiusSmall),
        boxShadow: enabled ? PixelTheme.shadowFor(edge) : const [],
      ),
      child: content,
    );

    if (!enabled) return body;
    return _PressSink(
      onTap: onPressed!,
      offset: PixelTheme.shadow,
      child: body,
    );
  }
}

/// Пиксельный чекбокс вместо материалового.
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
    final edge = PixelTheme.edge(context);
    final enabled = onChanged != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onChanged!(!value);
            }
          : null,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value
              ? PixelTheme.accent
              : (PixelTheme.isDark(context)
                    ? PixelTheme.darkSurfaceAlt
                    : PixelTheme.lightSurfaceAlt),
          border: Border.all(color: edge, width: PixelTheme.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: value
            ? PixelIcon('check', size: size - 6, color: Colors.white)
            : null,
      ),
    );
  }
}

/// Пиксельный переключатель: две позиции, никакого скользящего скругления.
class PixelSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const PixelSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = PixelTheme.isDark(context);
    final edge = PixelTheme.edge(context);
    final enabled = onChanged != null;
    const w = 46.0, h = 24.0, knob = 16.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onChanged!(!value);
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: value
                ? PixelTheme.accent
                : (dark ? PixelTheme.darkSurfaceAlt : PixelTheme.lightSurfaceAlt),
            border: Border.all(color: edge, width: PixelTheme.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 120),
            // Без плавной кривой: ручка «перещёлкивает», а не перетекает.
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: knob,
                height: knob - 4,
                decoration: BoxDecoration(
                  color: value ? Colors.white : edge,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Пиксельный radio.
class PixelRadio extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;
  final double size;

  const PixelRadio({
    super.key,
    required this.selected,
    required this.onTap,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final edge = PixelTheme.edge(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PixelTheme.isDark(context)
              ? PixelTheme.darkSurfaceAlt
              : PixelTheme.lightSurfaceAlt,
          border: Border.all(color: edge, width: PixelTheme.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: selected
            ? Container(
                width: size - 10,
                height: size - 10,
                color: PixelTheme.accent,
              )
            : null,
      ),
    );
  }
}

/// Заголовок секции — один из немногих мест, где пиксельный шрифт разрешён.
class PixelSectionTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const PixelSectionTitle(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: PixelTheme.heading(
          size: 8,
          color: PixelTheme.accent,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Строка настройки: слева иконка+тексты обычным шрифтом, справа контрол.
class PixelTile extends StatelessWidget {
  final String? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const PixelTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = PixelTheme.isDark(context);
    final fg = dark ? PixelTheme.darkText : PixelTheme.lightText;
    final dim = dark ? PixelTheme.darkTextDim : PixelTheme.lightTextDim;
    return PixelCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            PixelIcon(icon!, size: 20, color: PixelTheme.accent),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Обычный шрифт: это читаемый текст, а не акцентная метка.
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12.5, color: dim, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}
