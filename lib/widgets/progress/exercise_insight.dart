// ExerciseInsight — single editorial card showing one exercise's progress
// over the period. Numeral (01/02/03), italic name, fromTo numerals,
// sparkline on the right, coach voice quote under a hairline.
//
// Mirrors `ExerciseInsight` in vika-main-app-ivory-v1.jsx.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/progress_mock.dart';
import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';
class ExerciseInsight extends StatelessWidget {
  const ExerciseInsight({super.key, required this.mock});

  final ExerciseInsightMock mock;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mock.idx,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: c.inkFaint,
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PlanH1(
                      mock.name,
                      size: 22,
                      letterSpacing: -0.7,
                      height: 1,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          mock.from,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            color: c.inkFaint,
                            fontFeatures: VikaIvoryMain.tabularFigures,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '→',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 11,
                            color: c.inkGhost,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mock.to,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.3,
                            color: c.yellow,
                            fontFeatures: VikaIvoryMain.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                height: 40,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    mock.chart,
                    ink: c.ink,
                    yellow: c.yellow,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                const CoachMark(small: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mock.coach,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.1,
                      color: c.inkSoft,
                    ),
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

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, {required this.ink, required this.yellow});

  final List<int> values;
  final Color ink;
  final Color yellow;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV).abs();

    final w = size.width;
    final h = size.height - 4;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * w;
      final yNorm = range == 0 ? 0.5 : (values[i] - minV) / range;
      final y = h - yNorm * (h - 6) - 3;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );

    final lastIdx = values.length - 1;
    final lastX = w;
    final lastYNorm = range == 0 ? 0.5 : (values[lastIdx] - minV) / range;
    final lastY = h - lastYNorm * (h - 6) - 3;
    canvas.drawCircle(
      Offset(lastX, lastY),
      3,
      Paint()..color = yellow,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      !listEquals(oldDelegate.values, values);
}

bool listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
