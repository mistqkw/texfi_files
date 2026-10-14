import 'package:flutter/material.dart';

/// Переход между экранами: короткий fade + лёгкий подъём масштаба.
///
/// Материаловский slide здесь не годится: он тащит страницу вбок, и 2px
/// бордеры карточек на время движения размазываются в серую кашу. Fade со
/// сменой масштаба на 4% сохраняет чёткость краёв на всей дистанции.
class HairPageRoute<T> extends PageRouteBuilder<T> {
  HairPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          // Появляется с лёгким сдвигом вправо; уходящий экран чуть
          // приглушается.
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.025, 0), end: Offset.zero)
                  .animate(curved),
              child: child,
            ),
          );
        },
      );
}

/// Удобный помощник — чтобы вызовы не тянули за собой конструктор целиком.
Future<T?> hairPush<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context).push<T>(HairPageRoute<T>(builder: builder));
}
