import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';

class GlowRing extends StatelessWidget {
  const GlowRing({
    super.key,
    required this.valueLabel,
    required this.progress,
    required this.label,
    required this.color,
    required this.size,
  });

  final String valueLabel;
  final double progress;
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _GlowRingPainter(
                  progress: progress,
                  color: color,
                ),
              ),
              Center(
                child: Text(
                  valueLabel,
                  style: TextStyle(
                    fontSize: VFTheme.font(context, 18),
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4 * VFTheme.scale(context)),
        Text(
          label,
          style: TextStyle(
            fontSize: VFTheme.font(context, 10),
            fontWeight: FontWeight.w600,
            color: VFTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _GlowRingPainter extends CustomPainter {
  _GlowRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(4.5, size.width * 0.08).toDouble();
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    const start = -math.pi / 2;
    final sweep = (2 * math.pi) * progress.clamp(0.0, 1.0);
    final bounds = Rect.fromCircle(center: center, radius: radius);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final trackPaint = Paint()
      ..color = VFTheme.surfaceAlt
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: [color.withValues(alpha: 0.65), color],
      ).createShader(bounds)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(bounds, start, sweep, false, glowPaint);
    canvas.drawArc(bounds, start, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _GlowRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
