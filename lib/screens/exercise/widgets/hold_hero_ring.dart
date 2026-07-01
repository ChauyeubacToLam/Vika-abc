import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HoldHeroRing — the category-1 (time-based hold) centerpiece.
//
// Designed for a phone 2–2.5 m away: one large transparent ring center-screen
// with a ~90pt correct-seconds numeral inside. The camera mirror shows through
// the ring; center overlap with the user's body is an accepted tradeoff.
//
// The single most important thing this widget communicates is whether time is
// FLOWING or FROZEN. Seconds only accrue while form is correct, so the widget
// derives that state from the value itself: if [seconds] advances, time flows
// (warm yellow, breathing glow, numeral ticking); if it stops advancing while
// the hold is live, form broke (ring and numeral fall to dim grey, glow dies,
// numeral freezes). The two states crossfade smoothly — never a hard flash.
//
// Milestones (visual-only for now; earcons are a later pass):
//   • one soft pulse when crossing the halfway point
//   • during the final 5 seconds, a once-per-second heartbeat pulse on the
//     ring with a small scale-pop on the numeral (≤1Hz — photosensitivity)
//
// Completion hands off to the existing Hearthlight bloom; this widget renders
// nothing special at the end.
//
// No live form score or verdict lives here — flowing/frozen is a statement of
// fact about the timer, not a judgement. The verdict is computed after the set.
// ═══════════════════════════════════════════════════════════════════════════

class HoldHeroRing extends StatefulWidget {
  const HoldHeroRing({
    super.key,
    required this.seconds,
    required this.targetSeconds,
    this.diameter = 230,
  });

  /// Accrued correct seconds. Advancing means form is correct right now.
  final double seconds;

  /// Target seconds for the set.
  final double targetSeconds;

  final double diameter;

  @override
  State<HoldHeroRing> createState() => _HoldHeroRingState();
}

class _HoldHeroRingState extends State<HoldHeroRing>
    with TickerProviderStateMixin {
  /// 0 = frozen (dim grey), 1 = flowing (warm yellow). Smooth crossfade.
  late final AnimationController _flow;

  /// Gentle breathing of the glow while flowing.
  late final AnimationController _breath;

  /// Soft single pulse at the halfway milestone (~700ms).
  late final AnimationController _halfway;

  /// Once-per-second heartbeat in the final 5 seconds (fired per tick, ≤1Hz).
  late final AnimationController _beat;

  Timer? _freezeTimer;
  bool _passedHalfway = false;
  int _lastWholeSecond = -1;

  /// How long the value may sit still before we read it as frozen. Correct
  /// form advances the timer every frame (~30 FPS), so half a second of
  /// silence is an unambiguous break without flickering on frame jitter.
  static const Duration _freezeAfter = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 0,
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
      value: 0.5,
    )..repeat(reverse: true);
    _halfway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _beat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _lastWholeSecond = widget.seconds.floor();
    _passedHalfway = _progress >= 0.5;
  }

  @override
  void didUpdateWidget(HoldHeroRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seconds > oldWidget.seconds + 0.001) {
      _markFlowing();
      _fireMilestones();
    }
  }

  double get _progress => widget.targetSeconds <= 0
      ? 0.0
      : (widget.seconds / widget.targetSeconds).clamp(0.0, 1.0);

  double get _remaining =>
      (widget.targetSeconds - widget.seconds).clamp(0.0, double.infinity);

  void _markFlowing() {
    _flow.forward();
    _freezeTimer?.cancel();
    _freezeTimer = Timer(_freezeAfter, () {
      if (!mounted) return;
      _flow.reverse();
    });
  }

  void _fireMilestones() {
    // Halfway: one soft pulse, once per set.
    if (!_passedHalfway && _progress >= 0.5) {
      _passedHalfway = true;
      _halfway.forward(from: 0);
    }
    // Final 5 seconds: heartbeat once per accrued whole second. Seconds accrue
    // in real time, so this is naturally capped at 1Hz.
    final whole = widget.seconds.floor();
    if (whole != _lastWholeSecond) {
      _lastWholeSecond = whole;
      if (_remaining <= 5.0 && _remaining > 0) {
        _beat.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _freezeTimer?.cancel();
    _flow.dispose();
    _breath.dispose();
    _halfway.dispose();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation:
              Listenable.merge(<Listenable>[_flow, _breath, _halfway, _beat]),
          builder: (context, _) {
            final flow = Curves.easeInOut.transform(_flow.value);
            // Beat envelope: quick swell, soft release.
            final beat = math.sin(_beat.value * math.pi);
            final halfway = math.sin(_halfway.value * math.pi);
            // Ring scale carries the milestone pulses — transform only.
            final ringScale = 1.0 + halfway * 0.05 + beat * 0.03;
            final numeralScale = 1.0 + beat * 0.08;
            // Breathing glow only lives while time flows.
            final glow =
                flow * (0.30 + 0.30 * _breath.value + 0.35 * (beat + halfway));

            final ringColor = Color.lerp(
              VikaIvory.invInk.withValues(alpha: 0.34), // frozen: dim grey
              VikaIvory.yellow, // flowing: warm yellow
              flow,
            )!;
            final numeralColor = Color.lerp(
              VikaIvory.invInk.withValues(alpha: 0.42),
              VikaIvory.yellow,
              flow,
            )!;

            return Transform.scale(
              scale: ringScale,
              child: SizedBox(
                width: d,
                height: d,
                child: CustomPaint(
                  painter: _HoldRingPainter(
                    progress: _progress,
                    color: ringColor,
                    glowStrength: glow.clamp(0.0, 1.0),
                  ),
                  child: Center(
                    child: Transform.scale(
                      scale: numeralScale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The correct-seconds numeral — the hero. ~90pt,
                          // readable from across the room.
                          SizedBox(
                            height: d * 0.42,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${widget.seconds.floor()}',
                                style: TextStyle(
                                  fontFamily: VikaIvory.fontFamily,
                                  fontSize: 92,
                                  fontWeight: FontWeight.w800,
                                  color: numeralColor,
                                  letterSpacing: -3.5,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      color: VikaIvory.yellow
                                          .withValues(alpha: 0.55 * glow),
                                      blurRadius: 22,
                                    ),
                                    Shadow(
                                      color: VikaIvory.heroBg
                                          .withValues(alpha: 0.85),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Target — near-view detail only, deliberately small.
                          Text(
                            '/ ${widget.targetSeconds.round()} GIÂY',
                            style: TextStyle(
                              fontFamily: VikaIvory.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: Color.lerp(
                                VikaIvory.invInk.withValues(alpha: 0.30),
                                VikaIvory.invInkSoft,
                                flow,
                              ),
                              shadows: [
                                Shadow(
                                  color:
                                      VikaIvory.heroBg.withValues(alpha: 0.8),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HoldRingPainter extends CustomPainter {
  const _HoldRingPainter({
    required this.progress,
    required this.color,
    required this.glowStrength,
  });

  final double progress;
  final Color color;

  /// 0–1. Drives the breathing halo behind the arc. Zero while frozen.
  final double glowStrength;

  static const double _stroke = 11.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - _stroke) / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);

    // Track — the full circle, always faintly present so "how far from the
    // target" reads from the arc's gap alone. Transparent fill: the camera
    // stays the hero through the ring.
    final track = Paint()
      ..color = VikaIvory.invInk.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawArc(rect, startAngle, 2 * math.pi, false, track);

    // Breathing halo — only while flowing.
    if (glowStrength > 0.01 && sweep > 0.01) {
      final halo = Paint()
        ..color = color.withValues(alpha: 0.5 * glowStrength)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = _stroke + 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawArc(rect, startAngle, sweep, false, halo);
    }

    // Progress arc.
    if (sweep > 0.001) {
      final arc = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = _stroke;
      canvas.drawArc(rect, startAngle, sweep, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant _HoldRingPainter old) {
    return old.progress != progress ||
        old.color != color ||
        old.glowStrength != glowStrength;
  }
}
