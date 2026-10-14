import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles_ext.dart';
import 'hair_card.dart';
import 'hair_icons.dart';

/// Чекбокс: рамка 1px, радиус 3; при отметке заливка и линейная галочка.
class HairCheckbox extends StatelessWidget {
  const HairCheckbox({
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
              Haptics.tap();
              onChanged!(!value);
            }
          : null,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value ? colors.accent : Colors.transparent,
          borderRadius: AppRadius.controlSmallAll,
          border: Border.all(
            color: value ? colors.accent : colors.divider,
            width: AppRadius.hairline,
          ),
        ),
        child: value ? HairIcon('check', size: size - 4, color: colors.onAccent) : null,
      ),
    );
  }
}

/// Тумблер: дорожка-капсула 1px и круглый ползунок, плавно едущий вбок.
class HairSwitch extends StatelessWidget {
  const HairSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onChanged != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              Haptics.tap();
              onChanged!(!value);
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.standard,
          width: 44,
          height: 24,
          decoration: BoxDecoration(
            color: value ? colors.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value ? colors.accent : colors.divider,
              width: AppRadius.hairline,
            ),
          ),
          child: AnimatedAlign(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? colors.accent : colors.textTertiary,
                ),
                child: const SizedBox(width: 16, height: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Радио: кольцо 1px, внутри плавно вырастает точка акцента.
class HairRadio extends StatelessWidget {
  const HairRadio({
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
              Haptics.tap();
              onTap!();
            },
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.accent : colors.divider,
            width: AppRadius.hairline,
          ),
        ),
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.standard,
          width: selected ? size / 2.4 : 0,
          height: selected ? size / 2.4 : 0,
          decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Строка-карточка с иконкой, заголовком, подписью и хвостом.
class HairTile extends StatelessWidget {
  const HairTile({
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
    return HairCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            HairIcon(icon!, size: 20, color: colors.accent),
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
