import 'package:flutter/material.dart';

class FormScoreArc extends StatelessWidget {
  const FormScoreArc({
    super.key,
    required this.progress,
    required this.size,
    required this.color,
    this.child,
    this.strokeWidth = 6,
    this.trackColor = const Color(0x14000000),
    this.glow = false,
    this.duration = const Duration(milliseconds: 900),
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Widget? child;
  final bool glow;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: clamped),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _FormScoreArcPainter(
              progress: value,
              color: color,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
              glow: glow,
            ),
            child: Center(child: child),
          );
        },
      ),
    );
  }
}

class _FormScoreArcPainter extends CustomPainter {
  const _FormScoreArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.glow,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, -1.5708, 6.2831, false, trackPaint);

    if (glow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth * 2;
      canvas.drawArc(rect, -1.5708, 6.2831 * progress, false, glowPaint);
    }

    final arcPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.9),
          color,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, -1.5708, 6.2831 * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _FormScoreArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.glow != glow;
  }
}
