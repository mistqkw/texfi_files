import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Появление нового элемента списка: короткий подъём с проявлением.
///
/// Общий для всей ленты сообщений (home_page.dart) и списка устройств
/// (peers_page.dart) — «новый элемент появился» должно ощущаться одинаково
/// в обоих местах, а не быть двумя разными анимациями по совпадению формы.
///
/// [AnimationController] создаётся и уничтожается вместе с этим виджетом —
/// то есть вместе с конкретным элементом списка, а не живёт всё время
/// экрана: пока элемент виден на экране без изменений, анимация не
/// потребляет ни кадра.
class HairEntrance extends StatefulWidget {
  const HairEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<HairEntrance> createState() => _HairEntranceState();
}

class _HairEntranceState extends State<HairEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: AppMotion.standard,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(_curve),
      child: FadeTransition(opacity: _curve, child: widget.child),
    );
  }
}
