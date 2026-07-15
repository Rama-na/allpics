import 'dart:async';

import 'package:flutter/material.dart';

/// Fades + slides a list item in, delayed by its [index] for a staggered
/// cascade. Delay is capped so long lists don't crawl.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  static const _stepDelay = Duration(milliseconds: 40);
  static const _maxSteps = 8;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final CurvedAnimation _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, StaggeredEntrance._maxSteps);
    _timer = Timer(StaggeredEntrance._stepDelay * steps, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
