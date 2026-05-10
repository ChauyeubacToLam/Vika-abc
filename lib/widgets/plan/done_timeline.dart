// DoneTimeline — the layout for a completed week. WeekRecapCard leads (the
// dominant moment), then the day-by-day timeline with a left-side rail of
// circle nodes connected by per-row vertical line segments, capped by a
// TimelineTerminator that points to the next week.
//
// Per-row rail segments (rather than one absolute-positioned line behind
// all rows) ensure every row participates in the column's intrinsic
// height calculation — no risk of a row being silently dropped if the
// IntrinsicHeight + Stack-with-Positioned interaction misbehaves.
//
// Mirrors `DoneTimeline` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/plan_mock.dart';
import 'day_timeline_row.dart';
import 'week_recap_card.dart';

class DoneTimeline extends StatelessWidget {
  const DoneTimeline({
    super.key,
    required this.week,
    required this.nextWeek,
  });

  final PlanWeek week;
  final PlanWeek? nextWeek;

  @override
  Widget build(BuildContext context) {
    // Only render workout (non-rest) days in the timeline; rest days are
    // implied by the gaps in dates.
    final doneDays = week.days
        .where((d) => d.status == DayStatus.done)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WeekRecapCard(week: week),
        const SizedBox(height: 22),
        // Day rows. Each row owns its rail line segments above + below
        // its node circle, so they're naturally connected without any
        // absolute positioning gymnastics.
        for (var i = 0; i < doneDays.length; i++)
          DayTimelineRow(
            day: doneDays[i],
            isFirst: i == 0,
            isLast: i == doneDays.length - 1,
            // The whole done-week rail is fully completed (yellow).
            isCompleted: true,
          ),
        TimelineTerminator(currentWeek: week, nextWeek: nextWeek),
      ],
    );
  }
}
