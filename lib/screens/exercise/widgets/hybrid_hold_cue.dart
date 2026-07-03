import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HybridHoldCue — the category-2b (rep with mid-rep hold) checkpoint.
//
// A DRAINING countdown ring: it appears full and unwinds as the hold is
// served, with the seconds counting down inside, then bursts outward on the
// release beat ("LÊN!"). Rich enough to read as *time passing* from 2.5m —
// motion + a shrinking arc, not a text label.
//
// It must never be mistaken for the category-1 HoldHeroRing. The two can
// never actually share a screen (the set ring exists only in time-based
// exercises, this cue only in rep-based ones), and every structural axis is
// opposite:
//
//   • DRAINS (full → empty) — the set ring FILLS (empty → full)
//   • ~150pt — clearly smaller than 230pt
//   • lives seconds — the set ring lives the whole set
//
// Color is deliberately NOT spent on differentiation: the ring is yellow
// because that is the one color engineered to read at 2.5m — cream on a
// bright camera scene disappears. The cue is transient, so the momentary
// yellow surplus is within the design system's transient-moment exemption.
//
// The physical hold can be sub-second (squat: 0.35s), far too short for a
// human to read raw state changes. So this widget is a BEAT SEQUENCER, not a
// mirror: sub-second holds drain the ring over the 600ms minimum legible
// beat (the ring IS the beat) with a wordless GIỮ; holds long enough to
// count ([showCountdown]) drain on real progress with a per-second numeral
// pulse. Voice leads ("Giữ" → "Lên"); the screen lands the same beats at a
// readable tempo.
//
// The release moment is the loudest visual beat on purpose: the cue doubles
// as a safety cue — hesitating loaded at the bottom is bad. If the user does
// hesitate, LÊN! stays until they actually move (the parent keeps the cue
// alive through the bottom phase and ~650ms into the ascent).
//
// Per-second pulses only (≤1Hz); entrance/exit crossfades are owned by the
// parent AnimatedSwitcher.
// ═══════════════════════════════════════════════════════════════════════════

class HybridHoldCue extends StatefulWidget {
  const HybridHoldCue({
    super.key,
    required this.remainingSeconds,
    required this.readyToPush,
    this.progress = 0.0,
    this.showCountdown = true,
    this.diameter = 150,
  });

  /// Seconds left in the bottom hold; null when the exercise doesn't expose
  /// a numeric countdown.
  final double? remainingSeconds;

  /// True the instant the hold is served and the user should drive up.
  final bool readyToPush;

  /// Real hold progress 0–1 — drives the ring drain for countable holds.
  final double progress;

  /// Whether a numeric countdown means anything at this hold length. False
  /// for sub-second holds, whose ring drains over the minimum beat instead.
  final bool showCountdown;

  final double diameter;

  @override
  State<HybridHoldCue> createState() => _HybridHoldCueState();
}

class _HybridHoldCueState extends State<HybridHoldCue>
    with TickerProviderStateMixin {
  late final AnimationController _tick;
  late final AnimationController _release;

  /// Runs the GIỮ beat's minimum legible life — and, for sub-second holds,
  /// the ring drain itself. Vsync-driven so it stays honest under fake-async
  /// tests and janky frames alike.
  late final AnimationController _minBeat;

  /// Whether the release visual is actually showing — lags [widget.readyToPush]
  /// while the hold beat hasn't lived long enough to register.
  bool _showRelease = false;

  /// The exercise said "go up" before the GIỮ beat floor passed; fire the
  /// release the moment [_minBeat] completes.
  bool _pendingRelease = false;

  int _lastShownSecond = -1;

  /// Minimum time GIỮ stays on screen before LÊN! may replace it. Squat's
  /// physical hold is 0.35s; anything shorter than this floor is subliminal.
  static const Duration _minHoldBeat = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _release = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _minBeat = AnimationController(vsync: this, duration: _minHoldBeat)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _pendingRelease) {
          _fireRelease();
        }
      });
    _lastShownSecond = _displaySecond ?? -1;
    if (widget.readyToPush) {
      // Born in release (e.g. the lingering beat after a remount): show it.
      _showRelease = true;
      _release.value = 1;
    } else {
      _minBeat.forward();
    }
  }

  int? get _displaySecond {
    final remaining = widget.remainingSeconds;
    if (remaining == null) return null;
    return remaining.ceil().clamp(0, 99);
  }

  @override
  void didUpdateWidget(HybridHoldCue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.readyToPush && !oldWidget.readyToPush) {
      if (_minBeat.isCompleted) {
        _fireRelease();
      } else {
        _pendingRelease = true;
      }
      return;
    }
    if (!widget.readyToPush && oldWidget.readyToPush) {
      // Back into a fresh hold (user sank again before ascending).
      _pendingRelease = false;
      setState(() => _showRelease = false);
      _minBeat.forward(from: 0);
      return;
    }
    final second = _displaySecond;
    if (!widget.readyToPush && second != null && second != _lastShownSecond) {
      _lastShownSecond = second;
      _tick.forward(from: 0);
    }
  }

  void _fireRelease() {
    if (!mounted) return;
    _pendingRelease = false;
    setState(() => _showRelease = true);
    _release.forward(from: 0);
  }

  @override
  void dispose() {
    _tick.dispose();
    _release.dispose();
    _minBeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.diameter,
          height: widget.diameter,
          child: AnimatedBuilder(
            animation:
                Listenable.merge(<Listenable>[_tick, _release, _minBeat]),
            builder: (context, _) {
              return _showRelease ? _buildRelease() : _buildHold();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHold() {
    // The remaining fraction the ring still shows. Countable holds drain on
    // real progress; sub-second beat-holds drain over the minimum beat so
    // the drain is legible instead of a 350ms blink.
    final drain = widget.showCountdown
        ? (1.0 - widget.progress).clamp(0.0, 1.0)
        : (1.0 - _minBeat.value).clamp(0.0, 1.0);
    // Per-second pulse: brief swell as each second lands.
    final pulse = 1.0 + 0.07 * math.sin(_tick.value * math.pi);
    // Always show the seconds when the exercise exposes them — even a
    // sub-second beat reads better as "1" draining away than as a word.
    final second = _displaySecond;

    return Transform.scale(
      scale: pulse,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft dark pool inside the ring so the yellow numeral pops on any
          // camera scene — fades to nothing at the rim, mirror stays visible.
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
            // Smooth between coarse metric ticks so the drain never stutters.
            tween: Tween<double>(begin: drain, end: drain),
            duration: const Duration(milliseconds: 160),
            curve: Curves.linear,
            builder: (context, animatedDrain, child) {
              return CustomPaint(
                size: Size.square(widget.diameter),
                painter: DrainRingPainter(
                  fraction: animatedDrain,
                  color: VikaIvory.yellow,
                ),
                child: child,
              );
            },
            child: SizedBox.square(
              dimension: widget.diameter,
              child: Center(
                // The seconds alone, italic and huge — no label. The word is
                // the voice channel's job; the ring is the clock.
                child: second != null
                    ? Text(
                        '$second',
                        style: TextStyle(
                          fontFamily: VikaIvory.fontFamily,
                          fontSize: 74,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          color: VikaIvory.yellow,
                          letterSpacing: -2.5,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: VikaIvory.yellowGlow,
                              blurRadius: 20,
                            ),
                            Shadow(
                              color: VikaIvory.heroBg.withValues(alpha: 0.85),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelease() {
    // The loudest visual beat on the screen: the drained ring bursts outward
    // and dies while LÊN! pops in its place. Single decisive event, no loop.
    final t = _release.value.clamp(0.0, 1.0);
    final pop = Curves.easeOutBack.transform(t);
    final burst = Curves.easeOutCubic.transform(t);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ring shockwave — expands and fades.
        Opacity(
          opacity: (1.0 - burst).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 1.0 + 0.45 * burst,
            child: CustomPaint(
              size: Size.square(widget.diameter),
              painter: DrainRingPainter(
                fraction: 1.0,
                color: VikaIvory.yellow,
              ),
            ),
          ),
        ),
        Transform.scale(
          scale: 0.7 + 0.5 * pop,
          child: Text(
            'LÊN!',
            style: TextStyle(
              fontFamily: VikaIvory.fontFamily,
              fontSize: 64,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: VikaIvory.yellow,
              letterSpacing: -1.5,
              height: 1,
              shadows: [
                Shadow(color: VikaIvory.yellowGlow, blurRadius: 30),
                Shadow(
                  color: VikaIvory.heroBg.withValues(alpha: 0.85),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The draining arc: full circle at fraction 1.0, unwinding clockwise from
/// 12 o'clock as the hold is served. Transparent fill — the camera stays the
/// hero through the ring.
class DrainRingPainter extends CustomPainter {
  const DrainRingPainter({
    required this.fraction,
    required this.color,
    this.stroke = 9.0,
  });

  /// Remaining fraction of the hold, 1.0 → 0.0.
  final double fraction;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * fraction.clamp(0.0, 1.0);

    // Faint full track so the drained portion reads as "time already spent".
    final track = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, startAngle, 2 * math.pi, false, track);

    if (sweep > 0.001) {
      // Soft halo under the live arc — presence without competing with the
      // yellow set-level elements.
      final halo = Paint()
        ..color = color.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke + 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawArc(rect, startAngle, sweep, false, halo);

      final arc = Paint()
        ..color = color.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke;
      canvas.drawArc(rect, startAngle, sweep, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant DrainRingPainter old) {
    return old.fraction != fraction ||
        old.color != color ||
        old.stroke != stroke;
  }
}
