// Skeleton loaders for the Premium Ivory main app.
//
// The standard "wave" skeleton: lay out placeholder blocks that mirror the
// real content's structure + spacing, then sweep a soft highlight band across
// them on a gentle ~1.5s loop. This reads as "content is on the way" far
// better than a spinner or — worse — flashing mock data that then changes.
//
// Usage:
//   Shimmer(
//     inverted: onDarkHero,            // pick the right palette
//     child: Column(children: [
//       SkeletonBox(width: 160, height: 12),
//       SizedBox(height: 10),
//       SkeletonBox(width: 220, height: 34, radius: 9),
//     ]),
//   )
//
// Only wrap PURE-skeleton subtrees in [Shimmer] — its ShaderMask paints the
// sweep over every opaque pixel beneath it, so real text/logos placed inside
// would get swept too. Keep brand marks outside the Shimmer.
//
// Accessibility: honors the platform "reduce motion" setting — when motion is
// disabled the placeholders hold still (no sweep), per WCAG motion guidance.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Base + highlight tones for placeholders, resolved against the Premium
/// Ivory palette. [inverted] = placed on a warm-dark hero surface.
({Color base, Color highlight}) _skeletonTones(VikaColors c, bool inverted) {
  if (inverted) {
    return (
      base: Color.lerp(c.bgInverseHi, Colors.white, 0.10)!,
      highlight: Color.lerp(c.bgInverseHi, Colors.white, 0.20)!,
    );
  }
  return (
    base: Color.lerp(c.bgRaised, c.ink, 0.09)!,
    highlight: Color.lerp(c.bgRaised, c.ink, 0.035)!,
  );
}

/// A single rounded placeholder block. Opaque, so the [Shimmer] ancestor's
/// sweep reads cleanly across it; on its own (no shimmer / reduced motion) it
/// shows as a calm static tile in the base tone.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 7,
    this.inverted = false,
  });

  /// Null = expand to the parent's width (wrap in Expanded/SizedBox as needed).
  final double? width;
  final double height;
  final double radius;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _skeletonTones(c, inverted).base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A circular placeholder — avatars, timeline dots, medallions.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({
    super.key,
    required this.size,
    this.inverted = false,
  });

  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _skeletonTones(c, inverted).base,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Slides the highlight gradient horizontally across the masked bounds.
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slide);

  /// -1 = band off the left edge, 2 = band off the right edge.
  final double slide;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}

/// Wraps a subtree of [SkeletonBox]/[SkeletonCircle] placeholders and sweeps a
/// soft highlight band across them on a gentle ~1.5s loop.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.inverted = false,
  });

  final Widget child;

  /// True when placed over a warm-dark hero surface.
  final bool inverted;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Accessibility: respect the OS "reduce motion" preference — hold still.
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    final tones = _skeletonTones(VikaColors.of(context), widget.inverted);
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final slide = -1.0 + _ctrl.value * 3.0;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [tones.base, tones.highlight, tones.base],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlidingGradientTransform(slide),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
