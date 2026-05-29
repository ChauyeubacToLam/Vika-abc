// DoneThisWeek — small list of completed workouts in the CURRENT week.
//
// On a current-week page, the day strip shows T2 and T4 as tiny "76%" /
// "82%" indicators. That undersells what was actually done — those were
// real workouts. This widget gives them proper presentation as a
// 2-row list under the strip:
//
//   ┌──────────────────────────────────────────────────────┐
//   │ T2  Toàn thân nhẹ      · 4 bài    76% ▓▓▓▓▓▓░░       │
//   │ T4  Chân & Mông        · 5 bài    82% ▓▓▓▓▓▓▓░       │
//   └──────────────────────────────────────────────────────┘
//
// Editorial reading: "this is what you've done already this week" — quiet
// but acknowledged.

import 'package:flutter/material.dart';
import '../../data/plan_mock.dart';
import '../../theme/vf_theme.dart';
import '../../theme/app_colors.dart';

class DoneThisWeek extends StatelessWidget {
  const DoneThisWeek(
      {super.key,
      required this.days,
      required this.completed,
      required this.sessions});

  final List<PlanDay> days;
  final int completed;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final doneDays =
        days.where((d) => d.status == DayStatus.done).toList(growable: false);
    if (doneDays.isEmpty) return const SizedBox.shrink();

    // Section role is provided by the §02 "Tuần này" mark in WeekPage.
    // This widget just renders the cream card with the done rows.
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: c.bgRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < doneDays.length; i++) ...[
              _DoneRow(day: doneDays[i]),
              if (i < doneDays.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: c.border,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final form = day.form ?? 0;
    final high = form >= 80;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Italic Fraunces weekday letter — the editorial anchor.
          SizedBox(
            width: 30,
            child: Text(
              day.weekday,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.8,
                height: 1,
                color: c.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.count} bài · ${day.date}',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          // Form score pill — yellow for strong (≥80), cream for ok.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: high ? c.yellow : c.bg,
              borderRadius: BorderRadius.circular(999),
              border: high ? null : Border.all(color: c.border),
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$form',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: high ? c.yellowInk : c.ink,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                  TextSpan(
                    text: '%',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: high ? c.yellowInk : c.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
