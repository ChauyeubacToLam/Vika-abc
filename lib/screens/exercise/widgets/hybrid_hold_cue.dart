import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HybridHoldCue — the category-2b (rep with mid-rep hold) checkpoint.
//
// A squat-with-bottom-hold pauses loaded at the bottom for 1–3 seconds. This
// cue reads as "hold for a beat, then explode up" — and must never be
// mistaken for the category-1 HoldHeroRing. Differentiation is structural:
//
//   • counts DOWN ("GIỮ · 3 → 2 → 1"), the ring counts up
//   • no ring at all — a compact badge, clearly smaller than 230pt
//   • lives 1–3 seconds and disappears; the ring lives the whole set
//   • countdown is cream; yellow is saved for the release beat
//
// The release moment ("LÊN!") is the loudest visual beat on purpose: the cue
// doubles as a safety cue — hesitating loaded at the bottom is bad.
//
// Per-second pulse only (≤1Hz); entrance/exit crossfades are owned by the
// parent AnimatedSwitcher.
// ═══════════════════════════════════════════════════════════════════════════

class HybridHoldCue extends StatefulWidget {
  const HybridHoldCue({
    super.key,
    required this.remainingSeconds,
    required this.readyToPush,
  });

  /// Seconds left in the bottom hold; null when the exercise doesn't expose
  /// a numeric countdown (the badge then pulses wordlessly on "GIỮ").
  final double? remainingSeconds;

  /// True the instant the hold is served and the user should drive up.
  final bool readyToPush;

  @override
  State<HybridHoldCue> createState() => _HybridHoldCueState();
}

class _HybridHoldCueState extends State<HybridHoldCue>
    with TickerProviderStateMixin {
  late final AnimationController _tick;
  late final AnimationController _release;
  int _lastShownSecond = -1;

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
    _lastShownSecond = _displaySecond ?? -1;
    if (widget.readyToPush) _release.value = 1;
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
      _release.forward(from: 0);
      return;
    }
    final second = _displaySecond;
    if (second != null && second != _lastShownSecond) {
      _lastShownSecond = second;
      _tick.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    _release.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_tick, _release]),
          builder: (context, _) {
            return widget.readyToPush ? _buildRelease() : _buildCountdown();
          },
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    // Per-second pulse: brief swell as each second lands.
    final scale = 1.0 + 0.09 * math.sin(_tick.value * math.pi);
    final second = _displaySecond;

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
                fontSize: 30,
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
