import 'package:flutter/material.dart';

/// Переход между экранами: короткий fade + лёгкий подъём масштаба.
///
/// Материаловский slide здесь не годится: он тащит страницу вбок, и 2px
/// бордеры карточек на время движения размазываются в серую кашу. Fade со
/// сменой масштаба на 4% сохраняет чёткость краёв на всей дистанции.
class PixelPageRoute<T> extends PageRouteBuilder<T> {
  PixelPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
}

/// Удобный помощник — чтобы вызовы не тянули за собой конструктор целиком.
Future<T?> pixelPush<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context).push<T>(PixelPageRoute<T>(builder: builder));
}
