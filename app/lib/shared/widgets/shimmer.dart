import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Lightweight shimmer (no dependencies): a translating gradient swept over
/// skeleton shapes while content loads.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = (2 * _controller.value - 1) * bounds.width * 2;
            return LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds.shift(Offset(dx, 0)));
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A rounded placeholder block used inside skeleton layouts.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = double.infinity,
    this.radius = AppSpacing.radiusSm,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton for the album grid — mirrors the real grid's tile geometry.
class SkeletonAlbumGrid extends StatelessWidget {
  const SkeletonAlbumGrid({super.key, this.tileCount = 12});

  final int tileCount;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Shimmer(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
            ),
            itemCount: tileCount,
            itemBuilder: (_, _) => const SkeletonBox(),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for the home event list — card-shaped placeholders.
class SkeletonEventList extends StatelessWidget {
  const SkeletonEventList({super.key, this.cardCount = 3});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Shimmer(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cardCount,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, _) =>
                const SkeletonBox(height: 148, radius: AppSpacing.radiusLg),
          ),
        ),
      ),
    );
  }
}
