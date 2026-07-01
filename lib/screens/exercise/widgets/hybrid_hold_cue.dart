import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HybridHoldCue — the category-2b (rep with mid-rep hold) checkpoint.
//
// A squat-with-bottom-hold pauses loaded at the bottom; this cue reads as
// "hold for a beat, then explode up" — and must never be mistaken for the
// category-1 HoldHeroRing. Differentiation is structural:
//
//   • no ring at all — a compact badge, clearly smaller than 230pt
//   • lives around a second; the ring lives the whole set
//   • the hold beat is cream; yellow is saved for the release moment
//
// The physical hold can be sub-second (squat: 0.35s), far too short for a
// human to read raw state changes. So this widget is a BEAT SEQUENCER, not a
// mirror: GIỮ is guaranteed a minimum legible life (~600ms) before the
// release visual may replace it, even when the exercise reports readyToPush
// earlier. Voice leads ("Giữ" → "Lên"); the screen lands the same beats at a
// readable tempo. Holds long enough to count ([showCountdown]) get a
// per-second countdown numeral; sub-second holds show a single wordless GIỮ.
//
// The release moment ("LÊN!") is the loudest visual beat on purpose: the cue
// doubles as a safety cue — hesitating loaded at the bottom is bad. If the
// user does hesitate, LÊN! stays until they actually move (the parent keeps
// the cue alive through the bottom phase and ~650ms into the ascent).
//
// Per-second pulses only (≤1Hz); entrance/exit crossfades are owned by the
// parent AnimatedSwitcher.
// ═══════════════════════════════════════════════════════════════════════════

class HybridHoldCue extends StatefulWidget {
  const HybridHoldCue({
    super.key,
    required this.remainingSeconds,
    required this.readyToPush,
    this.showCountdown = true,
  });

  /// Seconds left in the bottom hold; null when the exercise doesn't expose
  /// a numeric countdown.
  final double? remainingSeconds;

  /// True the instant the hold is served and the user should drive up.
  final bool readyToPush;

  /// Whether a numeric countdown means anything at this hold length. False
  /// for sub-second holds (a flashing "· 1" reads as noise, not time).
  final bool showCountdown;

  @override
  State<HybridHoldCue> createState() => _HybridHoldCueState();
}

class _HybridHoldCueState extends State<HybridHoldCue>
    with TickerProviderStateMixin {
  late final AnimationController _tick;
  late final AnimationController _release;

  /// Runs the GIỮ beat's minimum legible life. Vsync-driven so it stays
  /// honest under fake-async tests and janky frames alike.
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
      duration: const Duration(milliseconds: 460),
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
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_tick, _release]),
          builder: (context, _) {
            return _showRelease ? _buildRelease() : _buildHold();
          },
        ),
      ),
    );
  }

  Widget _buildHold() {
    // Per-second pulse while counting; a steady presence for beat-holds.
    final scale = 1.0 + 0.09 * math.sin(_tick.value * math.pi);
    final second = widget.showCountdown ? _displaySecond : null;
    final holdLabelSize = second == null ? 46.0 : 30.0;

    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: VikaIvory.heroBg.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: VikaIvory.glass12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'GIỮ',
              style: TextStyle(
                fontFamily: VikaIvory.fontFamily,
                fontSize: holdLabelSize,
                fontWeight: FontWeight.w800,
                color: VikaIvory.invInk,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: VikaIvory.heroBg.withValues(alpha: 0.8),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
            if (second != null) ...[
              Text(
                ' · ',
                style: TextStyle(
                  fontFamily: VikaIvory.fontFamily,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: VikaIvory.invInkDim,
                ),
              ),
              Text(
                '$second',
                style: TextStyle(
                  fontFamily: VikaIvory.fontFamily,
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  color: VikaIvory.invInk,
                  letterSpacing: -2,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: VikaIvory.heroBg.withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRelease() {
    // The loudest visual beat on the screen: a single decisive pop, no loop.
    final t = Curves.easeOutBack.transform(_release.value.clamp(0.0, 1.0));
    return Transform.scale(
      scale: 0.7 + 0.5 * t,
      child: Text(
        'LÊN!',
        style: TextStyle(
          fontFamily: VikaIvory.fontFamily,
          fontSize: 74,
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
    );
  }
}
