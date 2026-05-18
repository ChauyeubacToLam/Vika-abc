// WeekDayStrip — horizontal strip of 7 vertical day cells used in the
// current and future week layouts. Replaces the older wide grid summary.
//
// Each cell shows weekday letter + date numeral + a status indicator at the
// bottom: form % (done), "HÔM NAY" pill (today), diamond (recheck), small
// outlined dot (planned), dash (rest).
//
// Mirrors `WeekDayStrip` and `WeekDayCell` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/plan_mock.dart';
import '../../theme/vf_theme.dart';
import '../../theme/app_colors.dart';
class WeekDayStrip extends StatelessWidget {
  const WeekDayStrip({
    super.key,
    required this.days,
    this.isFuture = false,
  });

  final List<PlanDay> days;
  final bool isFuture; // future weeks render with reduced opacity

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Opacity(
        opacity: isFuture ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: c.bgRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              for (final d in days) Expanded(child: _Cell(day: d)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final s = day.status;
    final isDone = s == DayStatus.done;
    final isToday = s == DayStatus.today;
    final isRecheck = s == DayStatus.recheck;
    final isPlanned = s == DayStatus.planned;
    final isRest = s == DayStatus.rest;

    final dateNum = day.date.split('/').first;

    final cellBg = isToday ? c.yellow : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: cellBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Weekday letter
          Text(
            day.weekday,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: isToday ? c.yellowInk : c.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          // Date numeral — italic display, tabular figures
          Text(
            dateNum,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.4,
              height: 1,
              fontFeatures: VikaIvoryMain.tabularFigures,
              color: isToday
                  ? c.yellowInk
                  : (isRest ? c.inkGhost : c.ink),
            ),
          ),
          const SizedBox(height: 6),
          // Status indicator
          SizedBox(
            height: 16,
            child: Center(
              child: _Indicator(
                day: day,
                isDone: isDone,
                isToday: isToday,
                isRecheck: isRecheck,
                isPlanned: isPlanned,
                isRest: isRest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.day,
    required this.isDone,
    required this.isToday,
    required this.isRecheck,
    required this.isPlanned,
    required this.isRest,
  });

  final PlanDay day;
  final bool isDone;
  final bool isToday;
  final bool isRecheck;
  final bool isPlanned;
  final bool isRest;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    if (isDone && day.form != null) {
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${day.form}',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
                color: c.ink,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
            TextSpan(
              text: '%',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: c.inkFaint,
              ),
            ),
          ],
        ),
      );
    }
    if (isToday) {
      return Text(
        'HÔM NAY',
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 7,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: c.yellowInk,
        ),
      );
    }
    if (isRecheck) {
      // Small diamond
      return Transform.rotate(
        angle: 0.785398, // 45°
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            border: Border.all(color: c.ink, width: 1.5),
          ),
        ),
      );
    }
    if (isPlanned) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.inkFaint, width: 1.5),
        ),
      );
    }
    if (isRest) {
      return Container(
        width: 8,
        height: 1.5,
        decoration: BoxDecoration(
          color: c.inkGhost,
          borderRadius: BorderRadius.circular(1),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
