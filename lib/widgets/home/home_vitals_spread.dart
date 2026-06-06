// HomeVitalsSpread — replaces the prior HomeVitalsPanel card with a
// magazine-style editorial spread laid directly on the cream canvas. No
// raised card, no enclosing frame — just typography and hairlines doing
// the structural work.
//
// Three tiers:
//
//   1. HEADER rail — 'TUẦN 03' on the left, hairline through, phase label
//      on the right. Editorial section break.
//
//   2. SESSIONS HERO STAT — asymmetric drop-cap composition:
//        Big italic "3" + smaller italic "/4" stacked, four progress dots
//        underneath, with the uppercase label "BUỔI ĐÃ XONG" + soft
//        italic standfirst sitting top-right anchored.
//
//   3. SUPPORTING METRICS row — streak on the left, form sparkline on
//      the right, separated by a single vertical hairline. Each metric
//      uses its own italic display numeral as the anchor.
//
// The whole composition reads like a Sunday-paper data spread. The
// raised-card stack-of-features look the user called out as "lazy" is
// gone — these stats now feel earned by the typography, not enclosed
// in a frame.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class HomeVitalsSpread extends StatelessWidget {
  const HomeVitalsSpread({
    super.key,
    required this.weekLabel,
    required this.phaseLabel,
    required this.sessionsDone,
    required this.sessionsTotal,
    required this.statusLine,
    required this.streakDays,
    required this.formPercent,
    required this.formDelta,
    required this.formWeek,
    this.padding = const EdgeInsets.fromLTRB(24, 36, 24, 0),
  });

  final String weekLabel; // 'TUẦN 03'
  final String phaseLabel; // 'NỀN TẢNG'

  final int sessionsDone;
  final int sessionsTotal;

  /// Short italic line that sits next to the sessions hero stat. Acts as
  /// a standfirst — e.g. 'Tuần đang đi đúng nhịp.' Soft-color italic.
  final String statusLine;

  final int streakDays;

  /// Mean form % over the current 7 days. Null = no sessions this week
  /// (cold start) — the block shows a muted placeholder instead of a numeral.
  final int? formPercent;

  /// Form % change vs the prior week. Null = no baseline (prior week had
  /// fewer than 2 sessions) — the delta pill is hidden entirely.
  final int? formDelta;

  /// Current-window raw scores, oldest-first. Fewer than 2 points hides the
  /// sparkline (it needs at least two to draw a segment).
  final List<int> formWeek;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderRail(weekLabel: weekLabel, phaseLabel: phaseLabel),
          const SizedBox(height: 28),
          _SessionsHero(
            done: sessionsDone,
            total: sessionsTotal,
            statusLine: statusLine,
          ),
          const SizedBox(height: 28),
          Container(height: 1, color: c.border),
          const SizedBox(height: 24),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _StreakBlock(days: streakDays)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(width: 1, color: c.border),
                ),
                Expanded(
                  child: _FormBlock(
                    percent: formPercent,
                    delta: formDelta,
                    week: formWeek,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HEADER RAIL
// ═══════════════════════════════════════════════════════════════

class _HeaderRail extends StatelessWidget {
  const _HeaderRail({required this.weekLabel, required this.phaseLabel});

  final String weekLabel;
  final String phaseLabel;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: c.yellow,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 11),
        Text(
          weekLabel,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: c.ink,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Container(height: 1, color: c.border)),
        const SizedBox(width: 14),
        Text(
          phaseLabel,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: c.inkSoft,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SESSIONS HERO — drop-cap stat
// ═══════════════════════════════════════════════════════════════

class _SessionsHero extends StatelessWidget {
  const _SessionsHero({
    required this.done,
    required this.total,
    required this.statusLine,
  });

  final int done;
  final int total;
  final String statusLine;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: drop-cap big italic numeral + denominator + progress dots
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$done',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 96,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -5.5,
                    height: 0.85,
                    color: c.ink,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 2),
                  child: Text(
                    '/ $total',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.8,
                      color: c.inkSoft,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SessionDots(done: done, total: total),
          ],
        ),
        const SizedBox(width: 18),
        // Right: label + italic standfirst, top-anchored so it sits up
        // against the drop-cap's optical top, creating that magazine
        // "headline + standfirst" gravity.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BUỔI ĐÃ XONG',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Container(width: 24, height: 1.5, color: c.yellow),
                const SizedBox(height: 12),
                Text(
                  statusLine,
                  maxLines: 3,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.1,
                    height: 1.45,
                    color: c.inkSoft,
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

class _SessionDots extends StatelessWidget {
  const _SessionDots({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? c.yellow : Colors.transparent,
              border: Border.all(
                color: i < done ? c.yellow : c.borderHi,
                width: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SUPPORTING METRICS — streak + form
// ═══════════════════════════════════════════════════════════════

class _StreakBlock extends StatelessWidget {
  const _StreakBlock({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LIÊN TIẾP',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: c.inkSoft,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$days',
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 44,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -2.4,
                height: 0.9,
                color: c.ink,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                'ngày',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormBlock extends StatelessWidget {
  const _FormBlock({
    required this.percent,
    required this.delta,
    required this.week,
  });

  /// Null when no session landed in the current 7 days — renders the muted
  /// cold-start placeholder instead of a numeral, and suppresses both the
  /// delta pill and the sparkline.
  final int? percent;

  /// Null when there is no prior-week baseline — the delta pill is hidden
  /// (we never render a misleading "↑+0" in place of "no data").
  final int? delta;

  /// Current-window scores, oldest-first. Fewer than 2 points hides the
  /// sparkline — `_SparklinePainter` divides by `week.length - 1`, so a
  /// single point would produce NaN.
  final List<int> week;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final percentValue = percent;
    final deltaValue = delta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'FORM 7 NGÀY',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: c.inkSoft,
          ),
        ),
        const SizedBox(height: 10),
        if (percentValue == null) ...[
          // Cold start: no session this week. Muted em-dash holds the
          // numeral's slot; no delta pill, no sparkline.
          Text(
            '—',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 44,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              height: 0.9,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Chưa có buổi tập tuần này',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.35,
              color: c.inkSoft,
            ),
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentValue',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -2.4,
                  height: 0.9,
                  color: c.ink,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              if (deltaValue != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.yellowGhost,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${deltaValue >= 0 ? '↑' : '↓'}'
                      '${deltaValue >= 0 ? '+' : ''}$deltaValue',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (week.length >= 2) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 18,
              child: CustomPaint(
                size: const Size.fromHeight(18),
                painter: _SparklinePainter(
                  week: week,
                  line: c.ink,
                  accent: c.yellow,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.week,
    required this.line,
    required this.accent,
  });

  final List<int> week;
  final Color line;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (week.isEmpty) return;
    final maxV = (week.reduce((a, b) => a > b ? a : b)).clamp(1, 100);
    final minV = (week.reduce((a, b) => a < b ? a : b)).clamp(0, 100);
    final range = (maxV - minV).clamp(1, 100);
    final dx = size.width / (week.length - 1);

    Offset point(int i) {
      final v = week[i].clamp(0, 100);
      final t = (v - minV) / range;
      final y = size.height - 2 - t * (size.height - 4);
      return Offset(i * dx, y);
    }

    final path = Path();
    for (var i = 0; i < week.length; i++) {
      final p = point(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);

    final last = point(week.length - 1);
    canvas.drawCircle(last, 3.5, Paint()..color = accent);
    canvas.drawCircle(
      last,
      3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = line,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.week != week || old.line != line || old.accent != accent;
}
