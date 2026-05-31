// StreakRing — circular progress ring showing how many days of the current
// week have been completed. Big italic day count in the center; "STREAK
// CAO NHẤT" badge pinned at the bottom.
//
// Mirrors `StreakRing` in vika-main-app-ivory-v1.jsx.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/vf_theme.dart';
import '../../theme/app_colors.dart';

class StreakRing extends StatelessWidget {
  const StreakRing({
    super.key,
    required this.days,
    required this.weekDots,
    this.label = 'NGÀY LIÊN TIẾP',
    this.badge = 'STREAK CAO NHẤT',
    this.size = 134,
  });

  final int days;
  final List<bool> weekDots; // 7-element list, true = completed
  final String label;
  final String badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final filled = weekDots.where((d) => d).length;
    final ratio = weekDots.isEmpty ? 0.0 : filled / weekDots.length;

    return Semantics(
      label: '$days ${label.toLowerCase()}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  ratio: ratio,
                  trackColor: c.borderHi,
                  yellow: c.yellow,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$days',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 50,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -3,
                      height: 0.9,
                      color: c.ink,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: c.inkFaint,
                    ),
                  ),
                ],
              ),
              // Badge pinned at the bottom.
              Positioned(
                bottom: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.ink,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: c.yellow,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.ratio,
    required this.trackColor,
    required this.yellow,
  });

  final double ratio;
  final Color trackColor;
  final Color yellow;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    if (ratio <= 0) return;

    // Filled arc with yellow → amber gradient.
    final rect = Rect.fromCircle(center: center, radius: radius);
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [yellow, const Color(0xFFE89A4B)],
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      ratio * 2 * math.pi,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}
