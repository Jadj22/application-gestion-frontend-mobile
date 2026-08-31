import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Fournit une animation de pulse partagée à tous les skeletons descendants.
class Skeleton extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const Skeleton({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1100),
  });

  static Animation<double>? animationOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SkeletonScope>()?.animation;
  }

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonScope(animation: _animation, child: widget.child);
  }
}

class _SkeletonScope extends InheritedWidget {
  final Animation<double> animation;

  const _SkeletonScope({required this.animation, required super.child});

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) =>
      animation != oldWidget.animation;
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return _Pulsing(
      child: Container(
        width: width,
        height: height ?? 14,
        decoration: BoxDecoration(
          color: AppColors.dashSurfaceContainer,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class SkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonText({
    super.key,
    this.width = 120,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(6),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }
}

class SkeletonAvatar extends StatelessWidget {
  final double size;

  const SkeletonAvatar({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) => SkeletonCircle(size: size);
}

class SkeletonImage extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonImage({
    super.key,
    this.width = 72,
    this.height = 72,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}

class SkeletonButton extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonButton({
    super.key,
    this.width = 140,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(999),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.dashSurfaceLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      child: child,
    );
  }
}

class SkeletonListItem extends StatelessWidget {
  final bool leadingCircle;
  final double leadingSize;

  const SkeletonListItem({
    super.key,
    this.leadingCircle = false,
    this.leadingSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (leadingCircle)
            SkeletonCircle(size: leadingSize)
          else
            SkeletonBox(
              width: leadingSize,
              height: leadingSize,
              borderRadius: BorderRadius.circular(8),
            ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 180, height: 14),
                SizedBox(height: 8),
                SkeletonText(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pulsing extends StatelessWidget {
  final Widget child;

  const _Pulsing({required this.child});

  @override
  Widget build(BuildContext context) {
    final animation = Skeleton.animationOf(context);
    if (animation == null) return child;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(animation),
      child: child,
    );
  }
}
