import 'package:flutter/material.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles_ext.dart';

/// Карточка (дизайн «hairline»): поверхность, рамка 1px, радиус 10, без
/// тени. На нажатие рамка плавно темнеет.
class HairCard extends StatefulWidget {
  const HairCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.onTap,
    this.onLongPress,
    this.accent = false,
    this.borderColor,
    this.background,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Выделенная карточка — рамка акцентом.
  final bool accent;

  final Color? borderColor;
  final Color? background;

  @override
  State<HairCard> createState() => _HairCardState();
}

class _HairCardState extends State<HairCard> {
  bool _pressed = false;

  bool get _tappable => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool v) {
    if (!_tappable || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    var border = widget.borderColor ??
        (widget.accent ? colors.accent.withValues(alpha: 0.6) : colors.divider);
    if (_pressed) border = colors.textTertiary;

    final content = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _pressed ? colors.surfaceVariant : (widget.background ?? colors.surface),
        borderRadius: AppRadius.cardMediumAll,
        border: Border.all(color: border, width: AppRadius.hairline),
      ),
      // ListTile и прочие Material-виджеты рисуют фон на ближайшем
      // Material-предке; без прослойки они оказались бы под заливкой.
      child: Material(type: MaterialType.transparency, child: widget.child),
    );

    if (!_tappable) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: content,
    );
  }
}

/// Заголовок раздела: подпись mono капсом и тонкая линия до края.
class HairSectionHeader extends StatelessWidget {
  const HairSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title.toUpperCase(),
              style: context.text.sectionTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppSpacing.wGapMd,
          Expanded(child: Container(height: AppRadius.hairline, color: colors.divider)),
          if (trailing != null) ...[AppSpacing.wGapMd, trailing!],
        ],
      ),
    );
  }
}

/// Тонкая линия 1px.
class HairDivider extends StatelessWidget {
  const HairDivider({super.key, this.gap = AppSpacing.md});

  final double gap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: gap),
      child: SizedBox(
        height: AppRadius.hairline,
        child: ColoredBox(color: context.colors.divider, child: const SizedBox.expand()),
      ),
    );
  }
}
