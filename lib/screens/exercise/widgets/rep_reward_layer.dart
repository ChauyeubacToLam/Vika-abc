import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// RepRewardLayer — "Living Ember Frame"
//
// An ambient, additive reward layer for the active exercise screen. The goal is
// a calm, expensive product that quietly celebrates effort and is readable from
// several meters away (the user props the phone across the room).
//
// The whole screen is framed in a soft, warm golden light — like the Siri /
// iOS-charging edge glow, or firelight catching the edges of the frame. It
// breathes continuously so the screen always feels alive ("glowing like fire"),
// and on every CLEAN rep the entire frame SWELLS: a slow ~1.5s bloom (not a
// blink) with a hotter white-gold flare riding the very edge — the luminous
// heart that reads as expensive rather than a flat tint. The resting glow grows
// richer as clean reps accumulate. A FAULTED rep is met with silence: the frame
// simply holds. Nothing here ever turns red, shrinks, or punishes.
//
// Product law honored:
//   • Glanceable — full-frame luminance + warm color + slow motion, not text.
//   • Additive only — clean reps reward; faults are silent; the resting glow
//     only ever rises across the set.
//   • No live verdict — there is no score on this screen.
//   • Center-safe — the warmth lives at the edges and fades to nothing through
//     the center, so the live body + jade skeleton stay fully visible.
//   • Premium Ivory tokens only — reserved yellow #FFB701 warming to cream
//     #FBF6EA at the hot edge. Never jade.
//   • Light on memory — pure gradient fills, no blur, no saveLayer, no cached
//     full-screen textures. Built to stay smooth on mid-range phones.
//   • Accessible — slow eases, no flicker/strobe; honors reduce-motion.
// ═══════════════════════════════════════════════════════════════════════════

class RepRewardLayer extends StatefulWidget {
  const RepRewardLayer({
    super.key,
    required this.cleanReps,
    required this.totalReps,
    required this.pulseId,
    this.holdProgress,
  });

  /// Cumulative count of clean reps this set. Only ever increases. Drives how
  /// rich the resting ember frame glows.
  final int cleanReps;

  /// Target rep count for the set — the resting glow fills toward "full"
  /// against this.
  final int totalReps;

  /// Increments exactly once per clean rep. A change fires a fresh swell.
  /// Faulted reps never bump this, so they produce no reward.
  final int pulseId;

  /// Continuous mode for time-based holds (category 1): when non-null, the
  /// resting pool level follows this 0–1 value (accrued correct seconds over
  /// the target) instead of cleanReps/totalReps, so the hearth rises with
  /// every correct second rather than in per-rep steps. The caller keeps it
  /// monotonic — the pool never falls mid-set. Completion still blooms
  /// through [pulseId] exactly like a clean rep.
  final double? holdProgress;

  @override
  State<RepRewardLayer> createState() => _RepRewardLayerState();
}

class _RepRewardLayerState extends State<RepRewardLayer>
    with TickerProviderStateMixin {
  // Transient full-frame swell, fired once per clean rep.
  late final AnimationController _bloom;

  // Slow, continuous "alive" breathing of the resting frame.
  late final AnimationController _breath;

  // 1.0 while the current swell is a milestone (every 5th clean rep), else 0.0.
  // A milestone flares hotter and brighter — significance carried by light.
  double _milestone = 0.0;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _bloom = AnimationController(
      vsync: this,
      // Slow, luxurious swell — deliberately not a blink.
      duration: const Duration(milliseconds: 1500),
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
      value: 0.5,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honor the platform "reduce motion" setting: freeze the continuous
    // breathing and let the painter drop the rising travel to a luminance-only
    // swell. The reward is still felt, just without continuous motion.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _reduceMotion = reduce;
    if (reduce) {
      if (_breath.isAnimating) _breath.stop();
      _breath.value = 0.5;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RepRewardLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulseId != oldWidget.pulseId && widget.pulseId > 0) {
      _milestone =
          (widget.cleanReps > 0 && widget.cleanReps % 5 == 0) ? 1.0 : 0.0;
      _bloom.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bloom.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseline = widget.holdProgress?.clamp(0.0, 1.0) ??
        (widget.totalReps <= 0
            ? 0.0
            : (widget.cleanReps / widget.totalReps).clamp(0.0, 1.0));

    return IgnorePointer(
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          // Ease the resting glow up whenever a clean rep lands.
          tween: Tween<double>(begin: 0, end: baseline),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, animatedBaseline, _) {
            return AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[_bloom, _breath]),
              builder: (context, __) {
                return CustomPaint(
                  painter: _EmberFramePainter(
                    baseline: animatedBaseline,
                    breath: _breath.value,
                    bloom: _bloom.value,
                    milestone: _milestone,
                    reduceMotion: _reduceMotion,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── The light itself ───────────────────────────────────────────────────────

class _EmberFramePainter extends CustomPainter {
  const _EmberFramePainter({
    required this.baseline,
    required this.breath,
    required this.bloom,
    required this.milestone,
    required this.reduceMotion,
  });

  /// 0–1 accumulation-driven resting intensity (clean reps / set target).
  final double baseline;

  /// 0–1 slow breathing phase.
  final double breath;

  /// 0–1 transient swell progress. 0 means no swell is playing.
  final double bloom;

  /// 1.0 if the active swell is a milestone, else 0.0.
  final double milestone;

  /// When true, the swell stays full-depth and only its luminance changes.
  final bool reduceMotion;

  static const Color _warm = VikaIvory.yellow; // reserved accent #FFB701
  static const Color _hot = VikaIvory.invInk; // warm cream highlight #FBF6EA

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Swell envelope — slow attack, gentle release. A breath of light, never a
    // blink: the brightness ramps over ~0.5s, holds, then fades over ~1s.
    double env = 0;
    if (bloom > 0.0001) {
      final attack =
          Curves.easeOutSine.transform((bloom / 0.34).clamp(0.0, 1.0));
      final release =
          bloom <= 0.34 ? 1.0 : (1 - (bloom - 0.34) / 0.66).clamp(0.0, 1.0);
      env = attack * Curves.easeInOutSine.transform(release);
    }

    // Resting frame — a faint living glow from the very start, growing with
    // clean reps, gently breathing so the screen always feels warm and alive.
    final breathMul = reduceMotion ? 1.0 : (0.80 + 0.20 * breath);
    final rest = ui.lerpDouble(0.20, 0.42, baseline)! * breathMul;
    final warmI = (rest + env * 0.46).clamp(0.0, 0.9);

    // The warm field — a generous golden vignette hugging all four edges, with
    // a luminous warm-cream tone right at the rim. Corners read brightest where
    // the bands overlap, framing the scene like firelight.
    _drawFrame(
      canvas,
      w,
      h,
      depthV: h * 0.30,
      depthH: w * 0.36,
      edgeColor: Color.lerp(_warm, _hot, 0.16)!,
      midColor: _warm,
      edgeAlpha: 0.60 * warmI,
      midAlpha: 0.20 * warmI,
    );

    // The hot flare — only during a swell, whiter and tucked tight to the very
    // edge. This luminous heart is what makes the moment feel expensive rather
    // than a flat wash. Milestones flare hotter and brighter still.
    if (env > 0.001) {
      final hotA = env * (0.34 + 0.30 * milestone);
      // Under reduce-motion keep the flare at full depth (luminance only);
      // otherwise let it ride a touch deeper at the peak for a sense of push.
      final depthBoost = reduceMotion ? 1.0 : (1.0 + 0.18 * env);
      _drawFrame(
        canvas,
        w,
        h,
        depthV: h * 0.17 * depthBoost,
        depthH: w * 0.20 * depthBoost,
        edgeColor: Color.lerp(_warm, _hot, 0.60 + 0.25 * milestone)!,
        midColor: Color.lerp(_warm, _hot, 0.25)!,
        edgeAlpha: 0.55 * hotA,
        midAlpha: 0.14 * hotA,
      );
    }
  }

  /// Paints a warm vignette frame: four edge bands that fade from the edge
  /// inward to transparent. Pure linear gradients — no blur, no layers.
  void _drawFrame(
    Canvas canvas,
    double w,
    double h, {
    required double depthV,
    required double depthH,
    required Color edgeColor,
    required Color midColor,
    required double edgeAlpha,
    required double midAlpha,
  }) {
    final eA = edgeAlpha.clamp(0.0, 1.0);
    final mA = midAlpha.clamp(0.0, 1.0);

    void band(Rect rect, Offset from, Offset to) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            from,
            to,
            <Color>[
              edgeColor.withValues(alpha: eA),
              midColor.withValues(alpha: mA),
              midColor.withValues(alpha: 0),
            ],
            const <double>[0.0, 0.42, 1.0],
          ),
      );
    }

    // Top
    band(Rect.fromLTWH(0, 0, w, depthV), Offset(0, 0), Offset(0, depthV));
    // Bottom
    band(Rect.fromLTWH(0, h - depthV, w, depthV), Offset(0, h),
        Offset(0, h - depthV));
    // Left
    band(Rect.fromLTWH(0, 0, depthH, h), Offset(0, 0), Offset(depthH, 0));
    // Right
    band(Rect.fromLTWH(w - depthH, 0, depthH, h), Offset(w, 0),
        Offset(w - depthH, 0));
  }

  @override
  bool shouldRepaint(covariant _EmberFramePainter old) {
    return old.baseline != baseline ||
        old.breath != breath ||
        old.bloom != bloom ||
        old.milestone != milestone ||
        old.reduceMotion != reduceMotion;
  }
}
