import 'package:flutter/material.dart';
import '../app.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String text;
  final String? image;
  const _Slide(this.icon, this.title, this.text, {this.image});
}

const _slides = <_Slide>[
  _Slide(Icons.bookmark_rounded, 'TexFi files',
      'Ваше «Избранное» — как в Telegram, только своё и без лимитов.',
      image: 'assets/brand/circle-icon.png'),
  _Slide(Icons.send_rounded, 'Шлите что угодно',
      'Текст, фото, видео и файлы любого размера — между вашими устройствами.'),
  _Slide(Icons.cloud_done_rounded, 'Аккаунт — ваше облако',
      'Войдите через GitHub, и файлы будут доступны с любого устройства из любой сети.'),
  _Slide(Icons.palette_rounded, 'Плеер и кастомизация',
      'Встроенный плеер с обложками, темы, дизайны Apple/Samsung, любые цвета и анимации.'),
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
    if (_index < _slides.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = _index == _slides.length - 1;
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
                  child: const Text('Пропустить'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) =>
                    _SlideView(slide: _slides[i], active: _index == i),
              ),
            ),
            const SizedBox(height: 8),
            _dots(cs),
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
                  child: Text(last ? 'Начать' : 'Далее',
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _slides.length; i++)
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
                  gradient: slide.image == null
                      ? LinearGradient(
                          colors: [cs.primary, cs.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  shape: BoxShape.circle,
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
