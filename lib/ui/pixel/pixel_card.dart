import 'package:flutter/material.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles_ext.dart';
import 'pixel_shadow.dart';

/// Карточка приложения: умеренно скруглённая (8–12), пиксельная рамка 2px
/// и сплошная ретро-тень со смещением — тем же приёмом, что у кнопок.
///
/// [raised] отвечает за тень. По умолчанию она есть: без неё карточки
/// читаются как плоские прямоугольники. Выключать стоит там, где карточка
/// вложена в другую или прижата к краю экрана.
class PixelCard extends StatefulWidget {
  const PixelCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.onTap,
    this.onLongPress,
    this.accent = false,
    this.borderColor,
    this.background,
    this.raised = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Выделенная карточка — рамка фирменным синим.
  final bool accent;

  final Color? borderColor;
  final Color? background;
  final bool raised;

  @override
  State<PixelCard> createState() => _PixelCardState();
}

class _PixelCardState extends State<PixelCard> {
  bool _pressed = false;

  bool get _tappable => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool v) {
    if (!_tappable || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border =
        widget.borderColor ?? (widget.accent ? colors.accent : colors.divider);

    final content = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.background ?? colors.surface,
        borderRadius: AppRadius.cardMediumAll,
        border: Border.all(color: border, width: AppRadius.pixelBorder),
      ),
      // ListTile и прочие Material-виджеты рисуют фон и отклик на ближайшем
      // Material-предке. Без этой прослойки они оказались бы под заливкой
      // карточки.
      child: Material(type: MaterialType.transparency, child: widget.child),
    );

    if (!widget.raised && !_tappable) return content;

    // Тень карточки — приглушённый вариант её же рамки: у акцентной синяя,
    // у обычной цвет разделителя.
    final shadowed = PixelShadowBox(
      shadowColor: widget.accent
          ? colors.accentShadow
          : (widget.borderColor ?? colors.divider),
      borderRadius: AppRadius.cardMediumAll,
      enabled: widget.raised,
      pressed: _pressed,
      child: content,
    );

    if (!_tappable) return shadowed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: shadowed,
    );
  }
}

/// Заголовок раздела пиксельным шрифтом с короткой «линейкой» справа —
/// делит экран на блоки без тяжёлых контейнеров.
class PixelSectionHeader extends StatelessWidget {
  const PixelSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Text(title, style: context.text.sectionTitle),
          AppSpacing.wGapMd,
          Expanded(child: Container(height: 2, color: colors.divider)),
          if (trailing != null) ...[AppSpacing.wGapMd, trailing!],
        ],
      ),
    );
  }
}

/// Разделитель внутри карточки.
///
/// Material `Divider` рисует линию в один логический пиксель — на плотном
/// экране это волосок, который рядом с рамками в [AppRadius.pixelBorder]
/// выглядит браком печати. Здесь [gap] — именно зазор с каждой стороны от
/// линии, а не полная высота коробки, как у Material.
class PixelDivider extends StatelessWidget {
  const PixelDivider({super.key, this.gap = AppSpacing.md});

  final double gap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: gap),
      child: SizedBox(
        height: AppRadius.pixelBorder,
        child: ColoredBox(
          color: context.colors.divider,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
