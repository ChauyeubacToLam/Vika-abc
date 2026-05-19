// PageHero — the section under the §01 mark: big italic week label, dates +
// phase + status meta, cumulative buổi count, and StatusSwipeDots in the
// top-right.
//
// Updates as the swiper changes activeWeek. This is the page's "where am I"
// anchor.
//
// Mirrors the in-page hero block of `PlanScreen` in
// vika-main-app-ivory-v1.jsx (the part right under SectionMark).

import 'package:flutter/material.dart';

import '../../data/plan_mock.dart';
import '../../theme/vf_theme.dart';
import 'plan_typography.dart';
import 'status_swipe_dots.dart';
import '../../theme/app_colors.dart';

class PageHero extends StatelessWidget {
  const PageHero({
    super.key,
    required this.weeks,
    required this.activeWeek,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 0),
  });

  final List<PlanWeek> weeks;
  final int activeWeek; // 1-based
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final week = weeks[activeWeek - 1];
    final totalDone = planTotalCompleted(weeks);
    final totalSessions = planTotalSessions(weeks);

    final statusSuffix = switch (week.status) {
      WeekStatus.done => ' · Đã xong',
      WeekStatus.future => ' · Sắp tới',
      WeekStatus.current => '',
    };

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlanH1(
                  'Tuần ${activeWeek.toString().padLeft(2, '0')}',
                  size: 46,
                  letterSpacing: -3,
                  height: 0.92,
                ),
                const SizedBox(height: 6),
                Text(
                  '${week.dates} · ${week.name}$statusSuffix',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: c.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalDone / $totalSessions buổi · ${week.name}',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          StatusSwipeDots(weeks: weeks, activeWeek: activeWeek),
        ],
      ),
    );
  }
}
