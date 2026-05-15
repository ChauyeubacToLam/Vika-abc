// LifetimeHero — warm-dark hero on Profile. "MỤC TIÊU CỦA BẠN" eyebrow,
// italic goal title, italic user-quote with yellow left border, lifetime
// stat trio (sessions / hours / form%), coach line.
//
// Mirrors `LifetimeStatsHero` and `LifetimeStat` in
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/profile_mock.dart';
import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';
class LifetimeHero extends StatelessWidget {
  const LifetimeHero({
    super.key,
    required this.goalTitle,
    required this.goalQuote,
    required this.stats,
    required this.coach,
    this.onEdit,
  });

  final String goalTitle;
  final String goalQuote;
  final List<ProfileLifetimeStat> stats;
  final String coach;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.yellow.withValues(alpha: 0.18),
                      c.yellow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: PlanEyebrow(
                      'MỤC TIÊU CỦA BẠN',
                      size: 9,
                      letterSpacing: 2,
                      color: c.yellow,
                    ),
                  ),
                  GestureDetector(
                    onTap: onEdit,
                    child: Text(
                      'SỬA',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: c.invInkFaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PlanH1('$goalTitle.', size: 26, dark: true, letterSpacing: -1.2,
                  height: 1),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 2, color: c.yellow),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '"$goalQuote"',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: c.invInkSoft,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Stats trio.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: c.borderDark),
                    bottom: BorderSide(color: c.borderDark),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      Expanded(
                        child: _StatTile(
                          stat: stats[i],
                          yellow: i == stats.length - 1,
                        ),
                      ),
                      if (i < stats.length - 1)
                        Container(
                          width: 1,
                          height: 32,
                          color: c.borderDark,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const CoachMark(small: true),
                  const SizedBox(width: 8),
                  PlanEyebrow(
                    'HUẤN LUYỆN VIÊN GHI',
                    size: 9,
                    letterSpacing: 1.6,
                    dark: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PlanP(
                coach,
                dark: true,
                italic: true,
                size: 14,
                letterSpacing: -0.2,
                height: 1.45,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, required this.yellow});

  final ProfileLifetimeStat stat;
  final bool yellow;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              stat.value,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 30,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -1.4,
                height: 0.85,
                color: yellow ? c.yellow : c.invInk,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              stat.unit,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: c.invInkSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        PlanEyebrow(stat.label, size: 9, letterSpacing: 1.4, dark: true),
      ],
    );
  }
}
