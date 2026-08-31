import 'package:flutter/material.dart';

/// Animation d'entrée explicite : fondu + glissement vertical.
///
/// À base de `AnimationController` (famille 2). Le paramètre [delay]
/// permet de créer des effets en cascade (staggering) entre éléments.
class AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;

  const AnimatedEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.08),
  });

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _fade = curve;
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero)
        .animate(curve);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}