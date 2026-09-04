import 'package:flutter/material.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_text_styles_ext.dart';

/// Логотип в шапке.
///
/// В экосистеме название всегда несёт небольшую графическую идею: у f0kus и
/// m0ney это подмена буквы цифрой. В «files» подменять нечего, поэтому идея
/// своя: часть названия набрана акцентом, а следом стоит пиксельный
/// блок-курсор — отсылка к терминальной строке, из которой приложение
/// выросло.
///
/// Курсор **не мигает постоянно**: это стоило бы перерисовки каждые полсекунды
/// всё время, пока открыт главный экран. Он отбивает несколько тактов только
/// в момент успешной передачи — как будто печатает подтверждение. Пасхалка,
/// которую замечаешь не сразу и только если смотрел в нужную секунду.
class PixelWordmark extends StatefulWidget {
  const PixelWordmark({super.key, required this.size, required this.leading});

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
  State<PixelWordmark> createState() => _PixelWordmarkState();
}

class _PixelWordmarkState extends State<PixelWordmark>
    with SingleTickerProviderStateMixin {
  /// Три полных такта «погас-зажёгся» примерно за 700 мс.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    PixelWordmark.pulses.addListener(_onPulse);
  }

  void _onPulse() {
    if (mounted) _blink.forward(from: 0);
  }

  @override
  void dispose() {
    PixelWordmark.pulses.removeListener(_onPulse);
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
        const SizedBox(width: 3),
        Padding(
          // Курсор садится на базовую линию текста, а не по центру строки.
          padding: EdgeInsets.only(bottom: widget.size * 0.12),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _blink,
              builder: (context, _) {
                // Вне анимации контроллер стоит на 0 и курсор просто горит:
                // ни одного лишнего кадра в покое.
                final on = _blink.isAnimating
                    ? (_blink.value * 6).floor().isEven
                    : true;
                return Container(
                  width: widget.size * 0.5,
                  height: widget.size * 0.5,
                  color: on ? colors.accent : Colors.transparent,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
