import 'package:flutter/material.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_text_styles_ext.dart';

/// Логотип в шапке: «TexFi» основным цветом, «files» акцентом и точка-
/// индикатор следом.
///
/// Точка **не пульсирует постоянно**: это стоило бы перерисовки всё время,
/// пока открыт главный экран. Она вспыхивает только в момент успешной
/// передачи — тихое подтверждение, которое замечаешь не сразу.
class HairWordmark extends StatefulWidget {
  const HairWordmark({super.key, required this.size, required this.leading});

  final double size;
  final double leading;

  /// Счётчик подтверждений. Отправка увеличивает его, логотип на это
  /// отвечает короткой серией миганий.
  ///
  /// Глобальный notifier, а не callback через полдерева: логотип живёт в
  /// шапке, а событие рождается в обработчике отправки, и связывать их
  /// цепочкой параметров ради трёх миганий не стоит.
  static final ValueNotifier<int> pulses = ValueNotifier<int>(0);

  static void blink() => pulses.value++;

  @override
  State<HairWordmark> createState() => _HairWordmarkState();
}

class _HairWordmarkState extends State<HairWordmark>
    with SingleTickerProviderStateMixin {
  /// Три полных такта «погас-зажёгся» примерно за 700 мс.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    HairWordmark.pulses.addListener(_onPulse);
  }

  void _onPulse() {
    if (mounted) _blink.forward(from: 0);
  }

  @override
  void dispose() {
    HairWordmark.pulses.removeListener(_onPulse);
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = context.text.screenTitle.copyWith(
      fontSize: widget.size,
      height: widget.leading,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'TexFi ', style: base),
                TextSpan(
                  text: 'files',
                  style: base.copyWith(color: colors.accent),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: EdgeInsets.only(bottom: widget.size * 0.2),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _blink,
              builder: (context, _) {
                // Точка-индикатор: в покое горит, на событие коротко
                // вспыхивает и плавно возвращается.
                final t = _blink.isAnimating ? Curves.easeOutCubic.transform(_blink.value) : 1.0;
                final pulse = _blink.isAnimating ? (1 - t) : 0.0;
                final d = widget.size * 0.22;
                return Container(
                  width: d + d * pulse,
                  height: d + d * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent,
                    boxShadow: pulse > 0
                        ? [BoxShadow(color: colors.accent.withValues(alpha: 0.5 * pulse), blurRadius: 10 * pulse)]
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
