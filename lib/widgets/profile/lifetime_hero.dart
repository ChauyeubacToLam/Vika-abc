// LifetimeHero — warm-dark card carrying the user's lifetime stats and
// the coach voice. Sits below the goal card on the Profile page.
//
// v2 split: goal title / quote / progress meter are now in the
// separate GoalCard widget. This file focuses on the stats trio +
// editorial kicker + coach line.

import 'package:flutter/material.dart';

import '../../data/profile_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';

class LifetimeHero extends StatelessWidget {
  const LifetimeHero({
    super.key,
    required this.stats,
    required this.coach,
    this.kicker = 'HÀNH TRÌNH TÍNH ĐẾN HÔM NAY',
  });

  final List<ProfileLifetimeStat> stats;
  final String coach;
  final String kicker;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(28),
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
          // Yellow radial wash, top-right.
          Positioned(
            top: -70,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.yellow.withValues(alpha: 0.22),
                      c.yellow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
            ),
          ),
          // Soft terracotta wash, bottom-left.
          Positioned(
            bottom: -110,
            left: -90,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x33CD7C45),
                      Color(0x00CD7C45),
                    ],
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
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.yellow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: c.yellow, blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    kicker,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: c.yellow,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // Stats trio inside its own hairline-bordered band.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: c.borderDark),
                    bottom: BorderSide(color: c.borderDark),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        Expanded(
                          child: _StatTile(
                            stat: stats[i],
                            yellow: i == stats.length - 1,
                          ),
                        ),
                        if (i < stats.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Container(width: 1, color: c.borderDark),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const CoachMark(small: true),
                  const SizedBox(width: 10),
                  PlanEyebrow(
                    'HUẤN LUYỆN VIÊN GHI',
                    size: 9.5,
                    letterSpacing: 1.6,
                    dark: true,
                  ),
                  const Spacer(),
                  Text(
                    '“',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      height: 0.4,
                      color: c.yellow.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              PlanP(
                coach,
                dark: true,
                italic: true,
                size: 14.5,
                letterSpacing: -0.2,
                height: 1.5,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // FittedBox keeps long values ("1.8", "74") from crossing the
          // hairline divider, matching the polish we did on Tien bo.
          SizedBox(
            height: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    stat.value,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -1.6,
                      height: 0.9,
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
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 14,
            height: 1,
            color: yellow ? c.yellow : c.invInkSoft.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: c.invInkSoft.withValues(alpha: 0.7),
            ),
          ),
          if (stat.delta != null) ...[
            const SizedBox(height: 4),
            Text(
              stat.delta!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                height: 1.3,
                letterSpacing: -0.1,
                color: yellow ? c.yellow : c.invInkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
