// LedgerFrame — the Progress tab's shared "fine-stationery" card shell.
//
// The page's two showpieces (StreakWeekStrip's jeweller's tray, ScoreGaugeCard's
// lit dark dial) earn "expensive" through material craft, not colour. This
// frame extracts that craft signature into one reusable shell so every cream
// supporting card on the page reads as a leaf of the same bound private ledger:
//
//   • a cream surface raked by a faint gold catch-light (top-right)
//   • deterministic paper grain (seeded — NEVER time-based, per design system)
//   • a DOUBLE-ENGRAVED frame: outer hairline + an inset ledger rule
//   • a layered warm shadow that lifts the leaf a few millimetres off the page
//
// It is pure chrome — callers compose their own content as [child]. Premium
// Ivory tokens only; theme-aware (cream in light, warm-dark in dark).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class LedgerFrame extends StatelessWidget {
  const LedgerFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 22),
    this.radius = 24,
    this.grainSeed = 71,
    this.catchLight = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// Seed for the deterministic paper grain. Vary per card so neighbouring
  /// leaves don't share an identical speckle pattern.
  final int grainSeed;

  /// The raking gold light in the top-right corner. On by default; off for
  /// cards that already carry their own atmospherics.
  final bool catchLight;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final innerRadius = math.max(radius - 6, 0.0);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: c.isDark ? 0.18 : 0.06),
            blurRadius: 32,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: c.ink.withValues(alpha: c.isDark ? 0.16 : 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // Layered cream surface, faintly warmed toward the gold corner.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color.lerp(
                          c.bgRaised, c.yellow, c.isDark ? 0.05 : 0.05)!,
                      c.bgRaised,
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
            // Gold catch-light raking the top-right corner.
            if (catchLight)
              Positioned(
                top: -74,
                right: -52,
                child: IgnorePointer(
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          c.yellow.withValues(alpha: 0.11),
                          c.yellow.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Deterministic paper grain — craft texture, never time-based.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _LedgerGrainPainter(
                    seed: grainSeed,
                    tint: c.ink,
                    alpha: c.isDark ? 0.05 : 0.022,
                  ),
                ),
              ),
            ),
            // Outer hairline.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: c.border),
                  ),
                ),
              ),
            ),
            // Inset engraved ledger rule.
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(innerRadius),
                      border: Border.all(
                        color: c.borderHi.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GRAIN — deterministic film grain (never time-based)
// ═══════════════════════════════════════════════════════════════

class _LedgerGrainPainter extends CustomPainter {
  _LedgerGrainPainter({
    required this.seed,
    required this.tint,
    required this.alpha,
  });

  final int seed;
  final Color tint;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final paint = Paint();
    final count = (size.width * size.height / 900).clamp(60, 420).toInt();
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final a = alpha * (0.4 + rnd.nextDouble() * 0.6);
      paint.color = tint.withValues(alpha: a);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LedgerGrainPainter old) =>
      old.seed != seed || old.tint != tint || old.alpha != alpha;
}
