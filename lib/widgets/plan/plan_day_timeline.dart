// PlanDayTimeline — the cream lower deck of the Plan page. Final polish:
// magazine-grade typography (38pt italic display date as the row anchor),
// more substantial timeline markers, premium expansion card, refined
// mini-row list with italic ledger indices, and a halo CTA inside the
// today row.
//
// Reads as a private training journal: each day is one editorial entry
// with the italic date as the visual anchor. The connecting line in the
// gutter ties them together into one journey.
//
// Tap a non-rest day → AnimatedSize reveals the day's exercise list +
// (for today) a halo "Bắt đầu" CTA. Today's row is expanded by default.
// Rest days don't expand. Recheck day has its own diamond marker and a
// separate CTA inside the expansion.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/plan_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class PlanDayTimeline extends StatefulWidget {
  const PlanDayTimeline({
    super.key,
    required this.days,
    required this.weekStatus,
    required this.weekNumber,
    required this.phaseName,
    this.onStartSession,
    this.onStartRetest,
    this.padding = const EdgeInsets.fromLTRB(24, 36, 24, 0),
  });

  final List<PlanDay> days;
  final WeekStatus weekStatus;
  final int weekNumber;
  final String phaseName;
  final VoidCallback? onStartSession;
  final VoidCallback? onStartRetest;
  final EdgeInsets padding;

  @override
  State<PlanDayTimeline> createState() => _PlanDayTimelineState();
}

class _PlanDayTimelineState extends State<PlanDayTimeline> {
  late Set<int> _expanded;
  late List<PlanDay> _lastDays;

  @override
  void initState() {
    super.initState();
    _lastDays = widget.days;
    _expanded = _initialExpansion(widget.days);
  }

  @override
  void didUpdateWidget(covariant PlanDayTimeline old) {
    super.didUpdateWidget(old);
    if (!identical(_lastDays, widget.days)) {
      _lastDays = widget.days;
      setState(() {
        _expanded = _initialExpansion(widget.days);
      });
    }
  }

  Set<int> _initialExpansion(List<PlanDay> days) {
    final out = <int>{};
    for (var i = 0; i < days.length; i++) {
      if (days[i].status == DayStatus.today) out.add(i);
    }
    return out;
  }

  void _toggle(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expanded.contains(i)) {
        _expanded.remove(i);
      } else {
        _expanded.add(i);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final sessionCount =
        widget.days.where((d) => d.status != DayStatus.rest).length;
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editorial section header — small, restrained, magazine-style.
          // Just enough to give the section a name without competing.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'TUẦN ${widget.weekNumber.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: c.ink,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.phaseName,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.1,
                  color: c.inkSoft,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Container(height: 1, color: c.border)),
              const SizedBox(width: 14),
              Text(
                '$sessionCount BUỔI',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: c.inkSoft,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < widget.days.length; i++)
            _DayRow(
              day: widget.days[i],
              expanded: _expanded.contains(i),
              onTap: widget.days[i].status == DayStatus.rest
                  ? null
                  : () => _toggle(i),
              isFirst: i == 0,
              isLast: i == widget.days.length - 1,
              weekStatus: widget.weekStatus,
              onStartSession: widget.onStartSession,
              onStartRetest: widget.onStartRetest,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DAY ROW
// ═══════════════════════════════════════════════════════════════

class _DayRow extends StatefulWidget {
  const _DayRow({
    required this.day,
    required this.expanded,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
    required this.weekStatus,
    this.onStartSession,
    this.onStartRetest,
  });

  final PlanDay day;
  final bool expanded;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;
  final WeekStatus weekStatus;
  final VoidCallback? onStartSession;
  final VoidCallback? onStartRetest;

  @override
  State<_DayRow> createState() => _DayRowState();
}

class _DayRowState extends State<_DayRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final day = widget.day;
    final isToday = day.status == DayStatus.today;
    final isDone = day.status == DayStatus.done;
    final isRest = day.status == DayStatus.rest;
    final isRecheck = day.status == DayStatus.recheck;
    final tappable = widget.onTap != null;

    return AnimatedScale(
      scale: _pressed ? 0.995 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: tappable ? (_) => setState(() => _pressed = true) : null,
        onTapUp: tappable ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: tappable ? () => setState(() => _pressed = false) : null,
        behavior: HitTestBehavior.opaque,
        // Stack instead of IntrinsicHeight+Row — IntrinsicHeight can't
        // compute a stable intrinsic size when AnimatedSize is changing
        // during expand/collapse, which caused the 258pt overflow. The
        // Stack sizes naturally to the padded content; the gutter
        // marker stretches to fill via Positioned(top:0, bottom:0).
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 42, bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RowHeader(
                    day: day,
                    isToday: isToday,
                    isDone: isDone,
                    isRecheck: isRecheck,
                    isRest: isRest,
                    tappable: tappable,
                    expanded: widget.expanded,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topLeft,
                    child: widget.expanded && !isRest
                        ? _RowExpansion(
                            day: day,
                            isToday: isToday,
                            isRecheck: isRecheck,
                            weekStatus: widget.weekStatus,
                            onStartSession: widget.onStartSession,
                            onStartRetest: widget.onStartRetest,
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
            // Marker gutter — stretches to full row height via
            // Positioned. Non-interactive so taps fall through to the
            // GestureDetector above.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 32,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DayMarkerPainter(
                    isFirst: widget.isFirst,
                    isLast: widget.isLast,
                    isToday: isToday,
                    isDone: isDone,
                    isRest: isRest,
                    isRecheck: isRecheck,
                    yellow: c.yellow,
                    ink: c.ink,
                    line: c.borderHi,
                    inkGhost: c.inkGhost,
                    inkFaint: c.inkFaint,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowHeader extends StatelessWidget {
  const _RowHeader({
    required this.day,
    required this.isToday,
    required this.isDone,
    required this.isRecheck,
    required this.isRest,
    required this.tappable,
    required this.expanded,
  });

  final PlanDay day;
  final bool isToday;
  final bool isDone;
  final bool isRecheck;
  final bool isRest;
  final bool tappable;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);

    final dateNum = day.date.split('/').first;

    final weekdayColor = isToday ? c.ink : (isRest ? c.inkFaint : c.inkSoft);
    final dateColor = isToday
        ? c.ink
        : isRest
            ? c.inkGhost
            : isDone
                ? c.inkSoft
                : c.ink;
    final titleColor = isToday
        ? c.ink
        : isRest
            ? c.inkFaint
            : isDone
                ? c.inkSoft
                : c.ink;

    final title = isRest
        ? 'Nghỉ'
        : day.title.isEmpty
            ? 'Buổi tập'
            : day.title;

    final summary = isRest
        ? ''
        : day.duration.isEmpty
            ? '${day.count} bài'
            : '${day.count} bài  ·  ${day.duration}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date block — eyebrow weekday + huge italic display date.
        SizedBox(
          width: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                day.weekday,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: weekdayColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateNum,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -2,
                  height: 0.9,
                  color: dateColor,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isToday || isRecheck) ...[
                  Row(
                    children: [
                      if (isToday)
                        _Pill(
                          label: 'HÔM NAY',
                          bg: c.yellow,
                          fg: c.yellowInk,
                        ),
                      if (isRecheck)
                        _Pill(
                          label: 'KIỂM TRA',
                          bg: c.yellowGhost,
                          fg: c.ink,
                          borderColor: c.yellow.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    color: titleColor,
                    fontStyle: isRest ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isDone && day.form != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.yellowGhost,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${day.form}% form',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                              fontFeatures: VikaIvoryMain.tabularFigures,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: c.inkFaint,
                            fontFeatures: VikaIvoryMain.tabularFigures,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (tappable) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              turns: expanded ? 0.5 : 0,
              child: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: isToday ? c.ink : c.inkFaint,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.bg,
    required this.fg,
    this.borderColor,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: fg,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EXPANSION — premium exercise list card
// ═══════════════════════════════════════════════════════════════

class _RowExpansion extends StatelessWidget {
  const _RowExpansion({
    required this.day,
    required this.isToday,
    required this.isRecheck,
    required this.weekStatus,
    this.onStartSession,
    this.onStartRetest,
  });

  final PlanDay day;
  final bool isToday;
  final bool isRecheck;
  final WeekStatus weekStatus;
  final VoidCallback? onStartSession;
  final VoidCallback? onStartRetest;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final exercises = day.exercises;
    if (exercises.isEmpty) return const SizedBox(width: double.infinity);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: c.bgRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderHi, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: c.ink.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: c.ink.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < exercises.length; i++) ...[
              _MiniRow(item: exercises[i], index: i + 1),
              if (i < exercises.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Container(height: 1, color: c.border),
                ),
            ],
            if (isToday &&
                weekStatus == WeekStatus.current &&
                onStartSession != null) ...[
              const SizedBox(height: 18),
              _MiniCta(
                label: day.title.isEmpty
                    ? 'Bắt đầu buổi này'
                    : 'Bắt đầu ${day.title}',
                onTap: onStartSession!,
              ),
            ],
            if (isRecheck && onStartRetest != null) ...[
              const SizedBox(height: 18),
              _MiniCta(
                label: 'Bắt đầu kiểm tra',
                onTap: onStartRetest!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.item, required this.index});
  final PlanExercise item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final nameColor = item.hasAi ? c.yellow : c.ink;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Italic tabular ledger index — gives the row a "set list" feel.
        SizedBox(
          width: 22,
          child: Text(
            index.toString().padLeft(2, '0'),
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.4,
              color: c.inkFaint,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: nameColor,
            ),
          ),
        ),
        if (item.volumeLabel.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            item.volumeLabel,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.inkFaint,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniCta extends StatefulWidget {
  const _MiniCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_MiniCta> createState() => _MiniCtaState();
}

class _MiniCtaState extends State<_MiniCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 0, 6, 0),
          height: 48,
          decoration: BoxDecoration(
            color: c.yellow,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.34),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: c.yellowInk,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: c.yellow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MARKER PAINTER
// ═══════════════════════════════════════════════════════════════

class _DayMarkerPainter extends CustomPainter {
  _DayMarkerPainter({
    required this.isFirst,
    required this.isLast,
    required this.isToday,
    required this.isDone,
    required this.isRest,
    required this.isRecheck,
    required this.yellow,
    required this.ink,
    required this.line,
    required this.inkGhost,
    required this.inkFaint,
  });

  final bool isFirst;
  final bool isLast;
  final bool isToday;
  final bool isDone;
  final bool isRest;
  final bool isRecheck;
  final Color yellow;
  final Color ink;
  final Color line;
  final Color inkGhost;
  final Color inkFaint;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Marker anchored to the date numeral's optical center (~28pt down
    // from the row top, given the 38pt italic display height).
    const markerCy = 28.0;

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 1.5;

    final markerHalf = _outerRadius();
    if (!isFirst) {
      canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, markerCy - markerHalf - 3),
        linePaint,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(cx, markerCy + markerHalf + 3),
        Offset(cx, size.height),
        linePaint,
      );
    }

    final markerCenter = Offset(cx, markerCy);
    if (isRest) {
      // Subtle dash — recedes from the visual rhythm
      final dash = Paint()
        ..color = inkGhost
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx - 7, markerCy),
        Offset(cx + 7, markerCy),
        dash,
      );
    } else if (isRecheck) {
      // Yellow diamond — fill + outline
      canvas.save();
      canvas.translate(cx, markerCy);
      canvas.rotate(0.785398); // 45°
      canvas.drawRect(
        const Rect.fromLTWH(-7, -7, 14, 14),
        Paint()..color = yellow.withValues(alpha: 0.22),
      );
      canvas.drawRect(
        const Rect.fromLTWH(-7, -7, 14, 14),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = yellow,
      );
      canvas.restore();
    } else if (isToday) {
      // Today is the dominant marker — wider halo, larger filled gold,
      // thin ink ring carved into it. Reads as a clear "you are here."
      canvas.drawCircle(
        markerCenter,
        14,
        Paint()
          ..color = yellow.withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(markerCenter, 9, Paint()..color = yellow);
      canvas.drawCircle(
        markerCenter,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = ink,
      );
    } else if (isDone) {
      // Done: filled gold with a thin inner ink ring — reads as a
      // "stamped" station that's been passed.
      canvas.drawCircle(markerCenter, 6, Paint()..color = yellow);
      canvas.drawCircle(
        markerCenter,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.black.withValues(alpha: 0.18),
      );
    } else {
      // Planned: hollow ring — empty station ahead.
      canvas.drawCircle(
        markerCenter,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = inkFaint,
      );
    }
  }

  double _outerRadius() {
    if (isToday) return 9;
    if (isRecheck) return 7;
    if (isRest) return 1;
    return 6;
  }

  @override
  bool shouldRepaint(covariant _DayMarkerPainter old) =>
      old.isFirst != isFirst ||
      old.isLast != isLast ||
      old.isToday != isToday ||
      old.isDone != isDone ||
      old.isRest != isRest ||
      old.isRecheck != isRecheck;
}
