import 'package:flutter/material.dart';
import '../app.dart';
import '../l10n/app_strings.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String text;
  final String? image;
  const _Slide(this.icon, this.title, this.text, {this.image});
}

List<_Slide> _buildSlides(AppStrings t) => [
      _Slide(Icons.bookmark_rounded, t.obTitle1, t.obText1,
          image: 'assets/logo.png'),
      _Slide(Icons.send_rounded, t.obTitle2, t.obText2),
      _Slide(Icons.cloud_done_rounded, t.obTitle3, t.obText3),
      _Slide(Icons.palette_rounded, t.obTitle4, t.obText4),
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
    final t = tr(context);
    final slides = _buildSlides(t);
    _count = slides.length;
    final last = _index == slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: last ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: last ? null : _finish,
                  child: Text(t.skip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) =>
                    _SlideView(slide: slides[i], active: _index == i),
              ),
            ),
            const SizedBox(height: 8),
            _dots(cs, slides.length),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(last ? t.start : t.next,
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots(ColorScheme cs, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _index ? cs.primary : cs.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final bool active;
  const _SlideView({required this.slide, required this.active});

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
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  // Для картинки-лого — заметная подложка и рамка, чтобы
                  // чёрный круг логотипа был виден на тёмном фоне.
                  color: slide.image != null
                      ? cs.surfaceContainerHighest
                      : null,
                  gradient: slide.image == null
                      ? LinearGradient(
                          colors: [cs.primary, cs.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  shape: BoxShape.circle,
                  border: slide.image != null
                      ? Border.all(color: cs.primary, width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                        color: cs.primary.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 4),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: slide.image != null
                    ? Image.asset(slide.image!, fit: BoxFit.cover)
                    : Icon(slide.icon, size: 76, color: cs.onPrimary),
              ),
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
                  Text(slide.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Text(slide.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
