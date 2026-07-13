import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';
import 'hybrid_hold_cue.dart' show DrainRingPainter;

// ═══════════════════════════════════════════════════════════════════════════
// RestCountdownRing — the in-set break for hold exercises.
//
// Protocols like the McGill plank (3 holds × 10s, 5s rest) rest INSIDE the
// set, on this screen. Anything that counts down gets a ring: this one
// drains amber — warm recovery, deliberately not the working yellow — with
// the seconds alone in the middle, italic and huge. The voice channel says
// "nghỉ"; the ring is the clock.
//
// Sits in the same center slot as the HoldHeroRing (they crossfade via the
// page's AnimatedSwitcher): work fills yellow and counts up, rest drains
// amber and counts down — opposite on every axis, unmistakable at 2.5m.
// ═══════════════════════════════════════════════════════════════════════════

class RestCountdownRing extends StatefulWidget {
  const RestCountdownRing({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.centerLabel,
    this.diameter = 210,
  });

  /// Seconds of rest left.
  final double remainingSeconds;

  /// Full rest length — drives the drain fraction.
  final double totalSeconds;

  /// Optional drained-state instruction in place of the countdown numeral.
  final String? centerLabel;

  final double diameter;

  @override
  State<RestCountdownRing> createState() => _RestCountdownRingState();
}

class _RestCountdownRingState extends State<RestCountdownRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  int _lastShownSecond = -1;

  /// Warm recovery amber — the transition screen's mid band, never the
  /// working yellow and never the fault orange.
  static const Color _amber = Color(0xFFE89A4B);

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _lastShownSecond = widget.remainingSeconds.ceil();
  }

  @override
  void didUpdateWidget(RestCountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final second = widget.remainingSeconds.ceil();
    if (second != _lastShownSecond) {
      _lastShownSecond = second;
      _tick.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drain = widget.totalSeconds <= 0
        ? 0.0
        : (widget.remainingSeconds / widget.totalSeconds).clamp(0.0, 1.0);
    final second = widget.remainingSeconds.ceil().clamp(0, 999);

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _tick,
          builder: (context, child) {
            // Per-second pulse: brief swell as each second lands.
            final pulse = 1.0 + 0.06 * math.sin(_tick.value * math.pi);
            return Transform.scale(scale: pulse, child: child);
          },
          child: SizedBox.square(
            dimension: widget.diameter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Dark pool so the amber numeral pops on any camera scene.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        VikaIvory.heroBg.withValues(alpha: 0.52),
                        VikaIvory.heroBg.withValues(alpha: 0),
                      ],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                  child: SizedBox.square(dimension: widget.diameter),
                ),
                TweenAnimationBuilder<double>(
                  // Smooth between per-frame ticks so the drain never jumps.
                  tween: Tween<double>(begin: drain, end: drain),
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.linear,
                  builder: (context, animatedDrain, child) {
                    return CustomPaint(
                      size: Size.square(widget.diameter),
                      painter: DrainRingPainter(
                        fraction: animatedDrain,
                        color: _amber,
                        stroke: 11,
                      ),
                      child: child,
                    );
                  },
                  child: SizedBox.square(
                    dimension: widget.diameter,
                    child: Center(
                      child: Text(
                        widget.centerLabel ?? '$second',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: VikaIvory.fontFamily,
                          fontSize: widget.centerLabel == null ? 88 : 26,
                          fontWeight: FontWeight.w800,
                          fontStyle: widget.centerLabel == null
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: _amber,
                          letterSpacing: widget.centerLabel == null ? -3 : -0.5,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: _amber.withValues(alpha: 0.55),
                              blurRadius: 22,
                            ),
                            Shadow(
                              color: VikaIvory.heroBg.withValues(alpha: 0.85),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
