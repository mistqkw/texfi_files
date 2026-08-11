import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Плавный скролл колёсиком мыши/тачпада на десктопе (как smooth scroll в
/// браузере). На мобильных — обычная физика (палец).
class SmoothScroll extends StatefulWidget {
  final ScrollController controller;
  final Widget Function(ScrollPhysics physics) builder;
  const SmoothScroll({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  State<SmoothScroll> createState() => _SmoothScrollState();
}

class _SmoothScrollState extends State<SmoothScroll> {
  static final bool _desktop =
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  double? _target;

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final c = widget.controller;
    if (!c.hasClients) return;
    final pos = c.position;
    final base = _target ?? c.offset;
    _target = (base + event.scrollDelta.dy)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    c
        .animateTo(
      _target!,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    )
        .whenComplete(() {
      if (_target != null && (c.offset - _target!).abs() < 1) _target = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_desktop) return widget.builder(const AlwaysScrollableScrollPhysics());
    return Listener(
      onPointerSignal: _onSignal,
      child: widget.builder(const NeverScrollableScrollPhysics()),
    );
  }
}
