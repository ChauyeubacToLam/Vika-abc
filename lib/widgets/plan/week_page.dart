// WeekPage — the per-week page in the horizontal swiper. Dispatches to one
// of three layouts based on PlanWeek.status:
//
//   • done    → DoneTimeline (recap card + day-by-day timeline + terminator)
//   • current → WeekFocusCard + §02 day strip + done list + TodayCard
//                + RecheckCard
//   • future  → FutureChapterCard + WeekDayStrip (muted)
//
// Inactive weeks fade to opacity 0.5 — the swipe transition feels intentional
// rather than just "scrolled past".

import 'package:flutter/material.dart';

import '../../data/plan_mock.dart';
import 'done_this_week.dart';
import 'done_timeline.dart';
import 'future_chapter_card.dart';
import 'recheck_card.dart';
import 'section_mark.dart';
import 'today_card.dart';
import 'week_day_strip.dart';
import 'week_focus_card.dart';

class WeekPage extends StatelessWidget {
  const WeekPage({
    super.key,
    required this.week,
    required this.isActive,
    required this.nextWeek,
    this.onStartToday,
    this.onStartRecheck,
  });

  final PlanWeek week;
  final bool isActive;
  final PlanWeek? nextWeek;
  final VoidCallback? onStartToday;
  final VoidCallback? onStartRecheck;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isActive ? 1 : 0.5,
      duration: const Duration(milliseconds: 220),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (week.status) {
      case WeekStatus.done:
        return DoneTimeline(week: week, nextWeek: nextWeek);

      case WeekStatus.current:
        final today = week.days.firstWhere(
          (d) => d.status == DayStatus.today,
          orElse: () => week.days.first,
        );
        final recheck =
            week.days.where((d) => d.status == DayStatus.recheck).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WeekFocusCard(week: week),
            // §02 section mark — gives the day strip + done list a
            // proper publication chapter break, mirroring the §01 mark
            // on the page hero. Padding tuned (8) so it lines up with
            // page-hero §01 (which uses 24px page padding; WeekPage has
            // 16px, so 8 inside = 24 total).
            const SectionMark(
              num: '02',
              label: 'Tuần này',
              total: '02',
              padding: EdgeInsets.fromLTRB(8, 28, 8, 0),
            ),
            WeekDayStrip(days: week.days),
            // Done-so-far list — gives T2 / T4 etc. proper presentation
            // beyond the single-cell form % in the day strip.
            DoneThisWeek(
              days: week.days,
              completed: week.completed,
              sessions: week.sessions,
            ),
            if (today.status == DayStatus.today)
              TodayCard(
                day: today,
                weekNum: week.num,
                onStart: onStartToday,
              ),
            if (recheck.isNotEmpty)
              RecheckCard(
                day: recheck.first,
                onStart: onStartRecheck,
              ),
          ],
        );

      case WeekStatus.future:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureChapterCard(week: week),
            WeekDayStrip(days: week.days, isFuture: true),
          ],
        );
    }
  }
}
