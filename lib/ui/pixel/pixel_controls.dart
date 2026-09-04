import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles_ext.dart';
import 'pixel_card.dart';
import 'pixel_icons.dart';

/// Пиксельный чекбокс вместо материалового.
class PixelCheckbox extends StatelessWidget {
  const PixelCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onChanged != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onChanged!(!value);
            }
          : null,
      child: AnimatedContainer(
        duration: AppMotion.instant,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value ? colors.accent : colors.surfaceVariant,
          borderRadius: AppRadius.controlSmallAll,
          border: Border.all(
            color: value ? colors.accent : colors.divider,
            width: AppRadius.pixelBorder,
          ),
        ),
        child: value
            ? PixelIcon('check', size: size - 6, color: colors.onAccent)
            : null,
      ),
    );
  }
}

/// Пиксельный переключатель: две позиции, ручка перещёлкивает, а не
/// перетекает — скользящее скругление здесь единственное место, где
/// движение было бы «мягким».
class PixelSwitch extends StatelessWidget {
  const PixelSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _w = 46;
  static const double _h = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onChanged != null;
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
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            color: value ? colors.accent : colors.surfaceVariant,
            borderRadius: AppRadius.controlSmallAll,
            border: Border.all(
              color: value ? colors.accent : colors.divider,
              width: AppRadius.pixelBorder,
            ),
          ),
          child: AnimatedAlign(
            duration: AppMotion.instant,
            curve: AppMotion.standard,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 16,
                height: 14,
                decoration: BoxDecoration(
                  color: value ? colors.onAccent : colors.textTertiary,
                  borderRadius: AppRadius.controlTinyAll,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Пиксельный radio — квадратный, с залитой сердцевиной.
class PixelRadio extends StatelessWidget {
  const PixelRadio({
    super.key,
    required this.selected,
    required this.onTap,
    this.size = 22,
  });

  final bool selected;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
          color: colors.surfaceVariant,
          borderRadius: AppRadius.controlSmallAll,
          border: Border.all(
            color: selected ? colors.accent : colors.divider,
            width: AppRadius.pixelBorder,
          ),
        ),
        child: selected
            ? Container(
                width: size - 10,
                height: size - 10,
                color: colors.accent,
              )
            : null,
      ),
    );
  }
}

/// Строка настройки: слева пиксельная иконка и читаемые тексты, справа
/// контрол. Заголовок и подпись набираются гротеском — это текст, который
/// читают, а не акцентная метка.
class PixelTile extends StatelessWidget {
  const PixelTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            PixelIcon(icon!, size: 20, color: colors.accent),
            AppSpacing.wGapMd,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text.tileTitle),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[AppSpacing.wGapMd, trailing!],
        ],
      ),
    );
  }
}
