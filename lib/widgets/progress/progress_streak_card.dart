// ProgressStreakCard — warm-dark streak card on Progress. Big italic 12 day
// count, summary line, 14 vertical bars (today brightest), Mon→TODAY axis.
//
// Mirrors `ProgressStreakCard` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';
class ProgressStreakCard extends StatelessWidget {
  const ProgressStreakCard({
    super.key,
    required this.days,
    required this.bars,
    required this.summary,
  });

  final int days;
  final List<bool> bars; // 14-element completion array
  final String summary;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: IgnorePointer(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.yellow.withValues(alpha: 0.16),
                      c.yellow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$days',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -2.5,
                      height: 0.9,
                      color: c.yellow,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ngày liên tiếp',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.3,
                      color: c.invInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              PlanP(summary, dark: true, soft: true, size: 12, height: 1.5),
              const SizedBox(height: 18),
              SizedBox(
                height: 22,
                child: Row(
                  children: [
                    for (var i = 0; i < bars.length; i++) ...[
                      Expanded(
                        child: Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: bars[i]
                                ? c.yellow
                                : c.invInk.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          // progressive opacity: today (last) brightest,
                          // older days fade.
                          foregroundDecoration: bars[i]
                              ? BoxDecoration(
                                  color: c.bgInverse.withValues(
                                    alpha: 1 -
                                        (i == bars.length - 1
                                            ? 1
                                            : 0.55 + (i / (bars.length - 1)) * 0.45),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                )
                              : null,
                        ),
                      ),
                      if (i < bars.length - 1) const SizedBox(width: 4),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PlanEyebrow('14 NGÀY TRƯỚC',
                      size: 9, letterSpacing: 1.2, dark: true),
                  PlanEyebrow('HÔM NAY',
                      size: 9, letterSpacing: 1.2, dark: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
