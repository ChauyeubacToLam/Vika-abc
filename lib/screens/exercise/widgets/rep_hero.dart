import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// IvoryRepHero — the category-2 (rep-based) hero.
//
// The rep count is the one number a rep-based user glances for from 2.5 m
// away, so it gets the luxury treatment: ~110pt numeral bottom-center with
// the set target small beside it, and a quick scale-pop on every counted rep.
//
// Everything that used to crowd this zone (phase verb, phase hint, 6px tally
// dots) is gone — illegible at distance, and the tally already lives on the
// transition replay and rest screens. Set progress survives as a slim
// underline beneath the numeral: gross proportion reads at any distance, and
// it costs zero text.
//
// No fault marking, no form verdict — the count is additive-only feedback;
// the verdict is computed after the set, never during.
// ═══════════════════════════════════════════════════════════════════════════

class IvoryRepHero extends StatefulWidget {
  const IvoryRepHero({
    super.key,
    required this.repCount,
    required this.totalReps,
  });

  final int repCount;
  final int totalReps;

  @override
  State<IvoryRepHero> createState() => _IvoryRepHeroState();
}

class _IvoryRepHeroState extends State<IvoryRepHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(IvoryRepHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repCount > oldWidget.repCount) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.repCount.clamp(0, widget.totalReps);
    final progress = widget.totalReps <= 0
        ? 0.0
        : (count / widget.totalReps).clamp(0.0, 1.0);

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pop,
          builder: (context, child) {
            // Quick swell-and-settle synchronized with the counted rep.
            final scale = 1.0 + 0.11 * math.sin(_pop.value * math.pi);
            return Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: VikaIvory.fontFamily,
                      fontSize: 110,
                      fontWeight: FontWeight.w800,
                      color: VikaIvory.yellow,
                      letterSpacing: -5,
                      height: 0.95,
                      shadows: [
                        Shadow(color: VikaIvory.yellowGlow, blurRadius: 26),
                        Shadow(
                          color: VikaIvory.heroBg.withValues(alpha: 0.8),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // The target is the second read ("am I almost done?") and
                  // must survive 2.5m too — bright cream, headline-sized,
                  // still clearly subordinate to the yellow count.
                  Text(
                    '/${widget.totalReps}',
                    style: TextStyle(
                      fontFamily: VikaIvory.fontFamily,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: VikaIvory.invInk,
                      letterSpacing: -1.5,
                      shadows: [
                        Shadow(
                          color: VikaIvory.heroBg.withValues(alpha: 0.85),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Slim set-progress underline — the tally dots' job at a size
              // that still means something across the room.
              SizedBox(
                width: 128,
                height: 4,
                child: Stack(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: VikaIvory.invInk.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const SizedBox.expand(),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: VikaIvory.yellow,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: VikaIvory.yellowGlowWeak,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
