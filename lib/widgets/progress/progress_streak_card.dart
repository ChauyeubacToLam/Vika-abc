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
    this.weeklyCompleted = 5,
    this.weeklyTotal = 7,
    this.nextMilestone = 15,
  });

  final int days;
  final List<bool> bars; // 14-element completion array
  final String summary;

  /// "Tuần này: X / Y" mini-summary that sits above the 14-day bars.
  final int weeklyCompleted;
  final int weeklyTotal;

  /// Hint banner under the bars: "N ngày nữa để đạt M".
  final int nextMilestone;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.yellow.withValues(alpha: 0.20),
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
              // Headline row — bigger day count + ngày liên tiếp.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$days',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 68,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -3.0,
                      height: 0.9,
                      color: c.yellow,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ngày',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.3,
                            height: 1,
                            color: c.invInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'LIÊN TIẾP',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                            color: c.invInkSoft.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              PlanP(summary, dark: true, soft: true, size: 12, height: 1.5),
              const SizedBox(height: 20),
              // Weekly mini-summary above the bar chart.
              Row(
                children: [
                  PlanEyebrow('TUẦN NÀY',
                      size: 9, letterSpacing: 1.4, dark: true),
                  const SizedBox(width: 10),
                  Text(
                    '$weeklyCompleted / $weeklyTotal',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.3,
                      color: c.yellow,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'buổi',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: c.invInkSoft.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    for (var i = 0; i < bars.length; i++) ...[
                      Expanded(
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: bars[i]
                                ? c.yellow
                                : c.invInk.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          // progressive opacity: today (last) brightest,
                          // older days fade.
                          foregroundDecoration: bars[i]
                              ? BoxDecoration(
                                  color: c.bgInverse.withValues(
                                    alpha: 1 -
                                        (i == bars.length - 1
                                            ? 1
                                            : 0.55 +
                                                (i / (bars.length - 1)) * 0.45),
                                  ),
                                  borderRadius: BorderRadius.circular(5),
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
              const SizedBox(height: 22),
              if (nextMilestone > days)
                _MilestoneFooter(
                  remaining: nextMilestone - days,
                  target: nextMilestone,
                )
              else
                const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

/// Integrated milestone footer — sits flush at the bottom of the
/// card under a hairline divider, like the masthead of a newspaper.
class _MilestoneFooter extends StatelessWidget {
  const _MilestoneFooter({required this.remaining, required this.target});
  final int remaining;
  final int target;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.borderDark),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.yellow,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.yellow.withValues(alpha: 0.36),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.flag_rounded,
              size: 14,
              color: c.yellowInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MỐC TIẾP THEO',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: c.invInkSoft.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: c.invInk,
                    ),
                    children: [
                      const TextSpan(text: 'Còn '),
                      TextSpan(
                        text: '$remaining ngày',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: c.yellow,
                        ),
                      ),
                      TextSpan(text: ' để đạt $target.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Big italic milestone numeral on the right, faint.
          Text(
            '$target',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -1.6,
              height: 1,
              color: c.invInk.withValues(alpha: 0.18),
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
