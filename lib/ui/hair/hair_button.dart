import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles_ext.dart';
import 'hair_icons.dart';

/// Кнопка (дизайн «hairline»): основная — заливка цветом текста, вторая —
/// прозрачная с рамкой 1px. Подпись — mono, капслок. Нажатие сдвигает
/// кнопку на 1px.
class HairButton extends StatefulWidget {
  const HairButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.expand = true,
    this.danger = false,
    this.compact = false,
  });

  final String label;

  /// `null` выключает кнопку.
  final VoidCallback? onPressed;

  /// Имя иконки из [HairGlyphs.all].
  final String? icon;

  final bool primary;
  final bool expand;
  final bool danger;
  final bool compact;

  @override
  State<HairButton> createState() => _HairButtonState();
}

class _HairButtonState extends State<HairButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final Color background;
    final Color foreground;
    final Color border;
    if (!_enabled) {
      background = widget.primary ? colors.surfaceVariant : Colors.transparent;
      foreground = colors.textTertiary;
      border = colors.divider;
    } else if (widget.danger) {
      background = colors.danger;
      foreground = Colors.white;
      border = colors.danger;
    } else if (widget.primary) {
      background = colors.textPrimary;
      foreground = colors.background;
      border = colors.textPrimary;
    } else {
      background = Colors.transparent;
      foreground = colors.textPrimary;
      border = _pressed ? colors.textPrimary : colors.divider;
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _enabled
            ? () {
                Haptics.tap();
                widget.onPressed!.call();
              }
            : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
          padding: EdgeInsets.symmetric(
            vertical: widget.compact ? AppSpacing.md : AppSpacing.lg,
            horizontal: widget.compact ? AppSpacing.lg : AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: _pressed && widget.primary && _enabled
                ? background.withValues(alpha: 0.88)
                : background,
            borderRadius: AppRadius.controlSmallAll,
            border: Border.all(color: border, width: AppRadius.hairline),
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                HairIcon(widget.icon!, size: 16, color: foreground),
                AppSpacing.wGapSm,
              ],
              Flexible(
                child: Text(
                  widget.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.buttonLabel.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
