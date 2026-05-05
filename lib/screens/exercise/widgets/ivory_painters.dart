import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Custom painters for the Ivory v8 active exercise screen.
//
// All painters use VikaIvory tokens. No third-party chart libraries.
// ═══════════════════════════════════════════════════════════════════════════════

/// Paints the 44px form-score arc (top-right chrome).
/// Circular track + progress stroke with glow.
class FormScoreArcPainter extends CustomPainter {
  const FormScoreArcPainter({
    required this.score,
    required this.arcColor,
  });

  /// 0–100 form score.
  final int score;

  /// Color of the progress stroke.
  final Color arcColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 3.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = VikaIvory.glass12
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, trackPaint);

    // Progress
    final sweepAngle = 2 * math.pi * (score / 100).clamp(0.0, 1.0);
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, arcPaint);

    // Glow layer
    final glowPaint = Paint()
      ..color = arcColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, glowPaint);
  }

  @override
  bool shouldRepaint(covariant FormScoreArcPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.arcColor != arcColor;
}

/// Paints a small sparkline chart (60×18) for form score history.
/// Filled area + stroke line + terminal dot.
class SparklinePainter extends CustomPainter {
  const SparklinePainter({required this.data});

  final List<int> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final w = size.width;
    final h = size.height;
    const minVal = 40.0;
    const maxVal = 100.0;

    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * w;
      final y = h - ((data[i] - minVal) / (maxVal - minVal)) * h;
      points.add(Offset(x, y));
    }

    // Fill
    final fillPath = Path()..moveTo(0, h);
    for (final pt in points) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(w, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          VikaIvory.yellow.withValues(alpha: 0.35),
          VikaIvory.yellow.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke
    final strokePath = Path();
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        strokePath.moveTo(points[i].dx, points[i].dy);
      } else {
        strokePath.lineTo(points[i].dx, points[i].dy);
      }
    }

    final strokePaint = Paint()
      ..color = VikaIvory.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(strokePath, strokePaint);

    // Terminal dot
    final lastPoint = points.last;
    final dotGlow = Paint()
      ..color = VikaIvory.yellowGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(lastPoint, 3, dotGlow);

    final dotPaint = Paint()..color = VikaIvory.yellow;
    canvas.drawCircle(lastPoint, 2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) =>
      oldDelegate.data != data;
}

/// Paints the 64px hold-timer ring with progress fill.
class HoldTimerRingPainter extends CustomPainter {
  const HoldTimerRingPainter({required this.progress});

  /// 0.0–1.0
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = VikaIvory.glass12
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, trackPaint);

    // Fill
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    final fillPaint = Paint()
      ..color = VikaIvory.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, fillPaint);

    // Glow
    final glowPaint = Paint()
      ..color = VikaIvory.yellowGlow
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, glowPaint);
  }

  @override
  bool shouldRepaint(covariant HoldTimerRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
