import 'package:flutter/material.dart';

/// Переход между экранами в пиксель-арт языке: короткий (170мс) fade с
/// едва заметным «доездом» масштаба, вместо стандартного Material-слайда.
///
/// Плавные длинные iOS-подобные слайды спорят с рубленой пиксельной
/// графикой: пока экран едет, чёткие 2px-рамки размазываются субпиксельным
/// сглаживанием. Короткий fade+scale держит кадры резкими и ощущается как
/// мгновенный отклик, а не как проигрывание анимации.
class PixelPageRoute<T> extends PageRouteBuilder<T> {
  PixelPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 170),
          reverseTransitionDuration: const Duration(milliseconds: 130),
          pageBuilder: (context, animation, secondary) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Удобный аналог `Navigator.push(MaterialPageRoute(...))` в едином стиле.
Future<T?> pixelPush<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    PixelPageRoute<T>(builder: (_) => page),
  );
}
