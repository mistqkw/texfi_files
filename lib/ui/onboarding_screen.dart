import 'package:flutter/material.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_spacing.dart';
import 'pixel/pixel_button.dart';
import 'pixel/pixel_card.dart';
import 'pixel/pixel_icons.dart';
import '../core/theme/app_colors_ext.dart';
import '../app.dart';
import '../l10n/app_strings.dart';
import 'terminal.dart';

class _Slide {
  /// Имя глифа из [PixelGlyphs].
  final String icon;
  final String title;
  final String text;
  const _Slide(this.icon, this.title, this.text);
}

List<_Slide> _buildSlides(AppStrings t) => [
      // Первый слайд — сам знак приложения, тот же, что в лаунчере и на
      // заставке.
      _Slide('node', t.obTitle1, t.obText1),
      _Slide('send', t.obTitle2, t.obText2),
      _Slide('exchange', t.obTitle3, t.obText3),
      _Slide('contrast', t.obTitle4, t.obText4),
    ];

/// Приветственный экран с анимациями — при первом запуске.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  int _count = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    AppScope.of(context).settings.onboardingSeen = true;
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _next() {
    if (_index < _count - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Терминальный вид стал единственным оформлением приложения, но
    // ветвления по нему в этом экране ещё остались — держим константу,
    // чтобы не переписывать раскладку целиком в рамках редизайна шапки.
    const terminal = true;
    final t = tr(context);
    final slides = _buildSlides(t);
    _count = slides.length;
    final last = _index == slides.length - 1;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  if (terminal)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '❯ ${_index + 1}/${slides.length}',
                        style: monoStyle(
                          color: cs.primary.withValues(alpha: 0.8),
                          size: 12,
                        ),
                      ),
                    ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: last ? 0 : 1,
                    duration: AppMotion.normal,
                    child: PixelButton(
                      label: t.skip,
                      expand: false,
                      compact: true,
                      primary: false,
                      onPressed: last ? null : _finish,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlideView(
                  slide: slides[i],
                  active: _index == i,
                  terminal: terminal,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _dots(cs, slides.length),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PixelButton(
                label: last ? t.start : t.next,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots(ColorScheme cs, int count) {
    final colors = _dotColors(cs);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: i == _index ? 22 : 8,
            height: 8,
            // Без скругления: капсула здесь была бы единственной мягкой
            // формой на экране.
            color: i == _index ? colors.$1 : colors.$2,
          ),
      ],
    );
  }

  (Color, Color) _dotColors(ColorScheme cs) => (cs.primary, cs.outline);
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final bool active;
  final bool terminal;
  const _SlideView({
    required this.slide,
    required this.active,
    required this.terminal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: active ? 1.0 : 0.7,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0.4,
              duration: const Duration(milliseconds: 300),
              child: _slideIcon(),
            ),
          ),
          const SizedBox(height: 48),
          AnimatedSlide(
            offset: active ? Offset.zero : const Offset(0, 0.2),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 350),
              child: Column(
                children: [
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: terminal ? cs.primary : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    slide.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: terminal
                          ? Colors.white70
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Терминальный вид: чёрный квадрат с белой рамкой вместо градиентного
  /// круга — та же врезанная подпись, что и у блоков в ленте.
  Widget _slideIcon() {
    return Builder(
      builder: (context) => PixelCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: PixelIcon(slide.icon, size: 96, color: context.colors.accent),
      ),
    );
  }

}
