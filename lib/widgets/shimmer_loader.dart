import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A sweeping highlight used to skeleton-load content.
///
/// Owns one [AnimationController], disposed in [dispose]. When the platform
/// asks for reduced motion the sweep is dropped and a flat placeholder is
/// drawn instead — still a skeleton, just not a moving one.
class Shimmer extends StatefulWidget {
  /// Wraps [child] in a sweeping highlight.
  const Shimmer({required this.child, super.key});

  /// The skeleton shapes to sweep across.
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;

    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final slide = (_controller.value * 2) - 0.5;
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              colors.shimmerBase,
              colors.shimmerHighlight,
              colors.shimmerBase,
            ],
            stops: <double>[
              (slide - 0.25).clamp(0.0, 1.0),
              slide.clamp(0.0, 1.0),
              (slide + 0.25).clamp(0.0, 1.0),
            ],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// A single skeleton block.
class ShimmerBox extends StatelessWidget {
  /// Creates a block of the given size.
  const ShimmerBox({
    required this.width,
    required this.height,
    super.key,
    this.radius = 8,
  });

  /// Block width. Pass [double.infinity] to fill the row.
  final double width;

  /// Block height.
  final double height;

  /// Corner radius.
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.mess.shimmerBase,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// The home screen's loading state.
///
/// Shaped like the real thing — a hero block with a countdown-sized bar and a
/// list of item rows, then three collapsed cards — so the transition to real
/// content does not shift the layout.
class HomeShimmer extends StatelessWidget {
  /// Creates the home skeleton.
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;

    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppTheme.pagePadding.add(
          const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius + 6),
              ),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ShimmerBox(width: 90, height: 10),
                  SizedBox(height: 14),
                  ShimmerBox(width: 160, height: 30),
                  SizedBox(height: 10),
                  ShimmerBox(width: 130, height: 12),
                  SizedBox(height: 22),
                  ShimmerBox(width: 220, height: 48, radius: 12),
                  SizedBox(height: 24),
                  ShimmerBox(width: double.infinity, height: 12),
                  SizedBox(height: 12),
                  ShimmerBox(width: double.infinity, height: 12),
                  SizedBox(height: 12),
                  ShimmerBox(width: 200, height: 12),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const ShimmerBox(width: 120, height: 12),
            const SizedBox(height: 14),
            for (var i = 0; i < 3; i++) ...<Widget>[
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ShimmerBox(width: 110, height: 18),
                    SizedBox(height: 10),
                    ShimmerBox(width: 170, height: 11),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// The week screen's loading state: a day strip plus four meal cards.
class WeekShimmer extends StatelessWidget {
  /// Creates the week skeleton.
  const WeekShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;

    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: AppTheme.pagePadding,
              itemCount: 7,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) =>
                  const ShimmerBox(width: 60, height: 78, radius: 16),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: AppTheme.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const ShimmerBox(width: 150, height: 20),
                const SizedBox(height: 18),
                for (var i = 0; i < 4; i++) ...<Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ShimmerBox(width: 110, height: 18),
                        SizedBox(height: 10),
                        ShimmerBox(width: 170, height: 11),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
