import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Custom painters for the Ivory v8 active exercise screen.
//
// All painters use VikaIvory tokens. No third-party chart libraries.
// ═══════════════════════════════════════════════════════════════════════════════

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
