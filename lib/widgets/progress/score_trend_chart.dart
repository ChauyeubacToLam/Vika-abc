// ScoreTrendChart — line chart that shows form-score over time. The
// "+14 from 60 to 74" delta is told as a number elsewhere; this chart
// is where it's *shown* as evidence. Reads like a financial paper's
// stock line — hairline grid, yellow line, terminal dot at "today."
//
// Period-aware: pass any List<int> of points and the chart fits.
// Faint X-axis tick labels at the start, middle, and end.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import 'ledger_frame.dart';

class ScoreTrendChart extends StatelessWidget {
  const ScoreTrendChart({
    super.key,
    required this.points,
    required this.startLabel,
    required this.midLabel,
    required this.endLabel,
    this.height = 180,
  });

  /// Series of integer form-scores (0–100). Length determines tick
  /// spacing; first = period start, last = today.
  final List<int> points;

  /// X-axis labels.
  final String startLabel;
  final String midLabel;
  final String endLabel;

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LedgerFrame(
        grainSeed: 29,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: c.yellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ĐIỂM HÔM NAY',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                              color: c.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${points.isEmpty ? 0 : points.last}',
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -1.8,
                              height: 0.95,
                              color: c.ink,
                              fontFeatures: VikaIvoryMain.tabularFigures,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '/ 100',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.inkFaint,
                                fontFeatures: VikaIvoryMain.tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (points.length >= 2)
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                    decoration: BoxDecoration(
                      color: c.ink,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: c.ink.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 13,
                          color: c.yellow,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${points.last - points.first} điểm',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.2,
                            color: c.yellow,
                            fontFeatures: VikaIvoryMain.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: height,
              child: LayoutBuilder(
                builder: (context, bc) => CustomPaint(
                  size: Size(bc.maxWidth, height),
                  painter: _TrendPainter(
                    points: points,
                    gridColor: c.border,
                    lineColor: c.ink,
                    fillColor: c.yellow,
                    labelColor: c.inkFaint,
                    calloutBg: c.ink,
                    calloutFg: c.invInk,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Hairline above axis labels — gives a "chart base" feel.
            Container(height: 1, color: c.border),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AxisTick(label: startLabel),
                _AxisTick(label: midLabel),
                _AxisTick(label: endLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisTick extends StatelessWidget {
  const _AxisTick({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: c.inkFaint,
        fontFeatures: VikaIvoryMain.tabularFigures,
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.gridColor,
    required this.lineColor,
    required this.fillColor,
    required this.labelColor,
    required this.calloutBg,
    required this.calloutFg,
  });
  final List<int> points;
  final Color gridColor;
  final Color lineColor;
  final Color fillColor;
  final Color labelColor;
  final Color calloutBg;
  final Color calloutFg;

  @override
  void paint(Canvas canvas, Size size) {
    // Need >= 2 points to draw a segment. This also guards the
    // `points.length - 1` divisor below: a 0/1-element series (no sessions,
    // or a single session) is skipped rather than producing NaN offsets.
    if (points.length < 2) return;

    const padTop = 14.0;
    const padBottom = 6.0;
    const padLeft = 0.0;
    const padRight = 0.0;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    final maxV = math.max(100, points.reduce(math.max));
    final minV = math.min(
      // Snap minV down by a small margin so the line never touches the
      // floor of the chart.
      math.max(0, points.reduce(math.min) - 5),
      points.reduce(math.min),
    );
    final range = (maxV - minV).toDouble();

    // Hairline horizontal grid (4 levels).
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = padTop + (chartH / 3) * i;
      // Draw as dashed line for editorial feel.
      _drawDashedLine(
        canvas,
        Offset(padLeft, y),
        Offset(padLeft + chartW, y),
        gridPaint,
        dashWidth: 2,
        gapWidth: 4,
      );
    }

    // Compute polyline points.
    final pts = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = padLeft + (chartW * i / (points.length - 1));
      final yNorm = (points[i] - minV) / range;
      final y = padTop + chartH - (yNorm * chartH);
      pts.add(Offset(x, y));
    }

    // Filled area under the line (yellow gradient soft wash).
    final fillPath = Path()..moveTo(pts.first.dx, padTop + chartH);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(pts.last.dx, padTop + chartH);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor.withValues(alpha: 0.30),
          fillColor.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromLTWH(padLeft, padTop, chartW, chartH),
      );
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line.
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }
    // Soft warm glow beneath the line — gives the ink a printed-emboss lift
    // off the cream rather than a flat plotted stroke.
    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = lineColor.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Ink stroke, brightening toward the terminal "today" point so the eye is
    // pulled left→right along the climb.
    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = ui.Gradient.linear(
          pts.first,
          pts.last,
          [Color.lerp(lineColor, labelColor, 0.35)!, lineColor],
        ),
    );

    // Faint start dot (anchor).
    canvas.drawCircle(
      pts.first,
      4,
      Paint()
        ..color = labelColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      pts.first,
      4,
      Paint()
        ..color = gridColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Bright "today" dot — terminal anchor.
    final last = pts.last;
    canvas.drawCircle(
      last,
      9,
      Paint()
        ..color = fillColor.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      last,
      6,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      last,
      3,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill,
    );

    // Today value callout — small ink pill above the dot with a
    // pointing tail. Reads like a stock-chart annotation.
    final todayValue = points.last;
    final calloutText = TextPainter(
      text: TextSpan(
        text: '$todayValue',
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          letterSpacing: -0.2,
          color: calloutFg,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pillW = calloutText.width + 14;
    const pillH = 20.0;
    // Anchor pill above the dot, but pull it left if too close to the
    // right edge so it doesn't clip.
    final pillCenterX = (last.dx + pillW / 2 > size.width)
        ? size.width - pillW / 2 - 2
        : last.dx;
    final pillRect = Rect.fromCenter(
      center: Offset(pillCenterX, last.dy - 22),
      width: pillW,
      height: pillH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(999)),
      Paint()..color = calloutBg,
    );
    // Pointer tail — a small downward triangle from pill to dot.
    final tailPath = Path()
      ..moveTo(last.dx - 4, pillRect.bottom - 1)
      ..lineTo(last.dx + 4, pillRect.bottom - 1)
      ..lineTo(last.dx, pillRect.bottom + 5)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = calloutBg);
    calloutText.paint(
      canvas,
      Offset(
        pillRect.left + (pillW - calloutText.width) / 2,
        pillRect.top + (pillH - calloutText.height) / 2,
      ),
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 4,
    double gapWidth = 4,
  }) {
    final total = (end - start).distance;
    final dx = (end.dx - start.dx) / total;
    final dy = (end.dy - start.dy) / total;
    double drawn = 0;
    while (drawn < total) {
      final segEnd = math.min(drawn + dashWidth, total);
      canvas.drawLine(
        Offset(start.dx + dx * drawn, start.dy + dy * drawn),
        Offset(start.dx + dx * segEnd, start.dy + dy * segEnd),
        paint,
      );
      drawn = segEnd + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      !_listEquals(old.points, points) ||
      old.lineColor != lineColor ||
      old.fillColor != fillColor;

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
