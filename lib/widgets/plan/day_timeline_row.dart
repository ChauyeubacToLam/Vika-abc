// DayTimelineRow + TimelineTerminator — the per-day rows and the
// "Tiếp theo: Tuần 0X" arrow row that closes a done week's timeline.
//
// Layout (rail on the LEFT — mirrors v3 left-rail timeline):
//   ┌──────┬─────────────────────────────────────────────────┐
//   │ rail │  card (T2 · Thứ Hai · 21/4 · ★ · 64%)            │
//   │  ●   │  Toàn thân nhẹ · 12 phút · 4 bài                 │
//   │ rail │  ┄┄┄┄ coach line ┄┄┄┄                            │
//   │      │  Squat   ▓▓▓▓▓░░ 72                              │
//   │      │  …                                                │
//   └──────┴─────────────────────────────────────────────────┘
//
// Best-day rows get a yellow node (with star) and a yellow right border on
// the card. Default rows have ink node with a yellow centre dot.
//
// Mirrors `DayTimelineRow` and `TimelineTerminator` in
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/plan_mock.dart';
import '../../theme/vf_theme.dart';
import 'exercise_form_bar.dart';
import 'plan_typography.dart';
import '../../theme/app_colors.dart';
class DayTimelineRow extends StatelessWidget {
  const DayTimelineRow({
    super.key,
    required this.day,
    required this.isLast,
    this.isFirst = false,
    this.isCompleted = true,
  });

  final PlanDay day;
  final bool isLast;
  final bool isFirst;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final isBest = day.isBest;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LEFT: per-row rail segment. Node circle is centered against
            // the card top; line segments above and below stretch the rest
            // of the row's height.
            //
            // Per-row segments (rather than a single absolute line behind
            // all rows) ensures every row is independently laid out — no
            // IntrinsicHeight + Stack-with-Positioned interaction quirks
            // that could drop a row.
            _RailSegment(
              isFirst: isFirst,
              isLast: isLast,
              isBest: isBest,
              isCompleted: isCompleted,
            ),
            const SizedBox(width: 18),
            // RIGHT: card.
            Expanded(child: _Card(day: day, isBest: isBest)),
          ],
        ),
      ),
    );
  }
}

/// Vertical rail column for a single timeline row: optional line segment
/// above the node, the node circle itself, optional line segment below.
class _RailSegment extends StatelessWidget {
  const _RailSegment({
    required this.isFirst,
    required this.isLast,
    required this.isBest,
    required this.isCompleted,
  });

  final bool isFirst;
  final bool isLast;
  final bool isBest;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final lineColor = isCompleted ? c.yellow : c.borderHi;
    return SizedBox(
      width: 22,
      child: Column(
        children: [
          // Top half line (hidden for first row).
          SizedBox(
            height: 14,
            child: isFirst
                ? const SizedBox.shrink()
                : Center(
                    child: Container(
                      width: 2,
                      color: lineColor,
                    ),
                  ),
          ),
          // Node circle. The 3px cream border + circle shape means the
          // line above and below appear to disappear behind the node.
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isBest ? c.yellow : c.ink,
              shape: BoxShape.circle,
              border: Border.all(color: c.bg, width: 3),
              boxShadow: [
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.08),
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: isBest
                ? Icon(
                    Icons.star_rounded,
                    size: 9,
                    color: c.ink,
                  )
                : Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.yellow,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
          // Bottom half line — fills the remainder of the row's height.
          // Drawn even on isLast=true to connect into the
          // TimelineTerminator below.
          Expanded(
            child: Center(
              child: Container(
                width: 2,
                color: lineColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.day, required this.isBest});

  final PlanDay day;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, isBest ? 14 : 16, 14),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          top: BorderSide(color: c.border),
          left: BorderSide(color: c.border),
          bottom: BorderSide(color: c.border),
          right: BorderSide(
            color: isBest ? c.yellow : c.border,
            width: isBest ? 3 : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(day: day, isBest: isBest),
          const SizedBox(height: 10),
          PlanH1(
            day.title,
            size: 17,
            italic: true,
            letterSpacing: -0.5,
            height: 1.1,
          ),
          const SizedBox(height: 3),
          Text(
            '${day.duration} · ${day.count} bài',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: c.inkFaint,
            ),
          ),
          if (day.coach != null) ...[
            const SizedBox(height: 12),
            // Dashed top border for the coach divider — Flutter doesn't
            // render dashed borders without a CustomPainter, so we
            // approximate with a 1px hairline. The italic coach line
            // alongside the CoachMark glyph keeps the same hierarchy.
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: CoachMark(small: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PlanP(
                      day.coach!,
                      soft: true,
                      italic: true,
                      size: 13,
                      letterSpacing: -0.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Column(
            children: [
              for (final ex in day.exercises) ExerciseFormBar(exercise: ex),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.day, required this.isBest});

  final PlanDay day;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day.weekday,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.5,
                  height: 0.85,
                  color: c.ink,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlanEyebrow(
                      day.weekdayLong.toUpperCase(),
                      size: 9,
                      letterSpacing: 1.4,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.date,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBest) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.yellowGhost,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 9,
                          color: c.yellow,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'ĐỈNH',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: c.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Form % pill.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isBest ? c.yellow : c.bg,
            borderRadius: BorderRadius.circular(999),
            border: isBest
                ? null
                : Border.all(color: c.border),
          ),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${day.form ?? 0}',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isBest ? c.yellowInk : c.ink,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
                TextSpan(
                  text: '%',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isBest
                        ? c.yellowInk
                        : c.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── TimelineTerminator ─────────────────────────────────────────────────────
// "Tiếp theo: Tuần 0X · Phase name" pointer at the bottom of a done week's
// timeline. Mirrors `TimelineTerminator` in vika-main-app-ivory-v1.jsx.
class TimelineTerminator extends StatelessWidget {
  const TimelineTerminator({
    super.key,
    required this.currentWeek,
    required this.nextWeek,
  });

  final PlanWeek currentWeek;
  final PlanWeek? nextWeek;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    if (nextWeek == null) return const SizedBox.shrink();
    final isCurrentNext = nextWeek!.status == WeekStatus.current;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Terminator rail column: short top line, then the arrow node.
            SizedBox(
              width: 22,
              child: Column(
                children: [
                  // Short bit of line continuing from the last row.
                  SizedBox(
                    height: 4,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: c.borderHi,
                      ),
                    ),
                  ),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: c.bg,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: c.borderHi, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 10,
                      color: c.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Tiếp theo: ',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: c.inkFaint,
                      ),
                    ),
                    Text(
                      'Tuần ${nextWeek!.num.toString().padLeft(2, '0')} · ${nextWeek!.name}',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    if (isCurrentNext) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.yellow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'HIỆN TẠI',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: c.yellowInk,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
