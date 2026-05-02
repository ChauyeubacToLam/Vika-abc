import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

class SkeletonCallout {
  const SkeletonCallout({
    required this.title,
    required this.value,
    required this.color,
    required this.alignment,
    required this.anchor,
    this.showAiTag = true,
  });

  final String title;
  final String value;
  final Color color;
  final Alignment alignment;
  final Offset anchor;
  final bool showAiTag;
}

class SkeletonAnnotation extends StatelessWidget {
  const SkeletonAnnotation({
    super.key,
    required this.callouts,
  });

  final List<SkeletonCallout> callouts;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.32,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth * 0.31;
          final cardLeftFactor =
              ((constraints.maxWidth - cardWidth - 8) / constraints.maxWidth)
                  .clamp(0.68, 0.76);
          final yFractions = _targetFractions(callouts.length);

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _SkeletonPainter(
                    callouts: callouts,
                    cardLeftFactor: cardLeftFactor,
                    targetFractions: yFractions,
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: cardWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: callouts
                            .map(
                              (callout) =>
                                  _SkeletonCalloutCard(callout: callout),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<double> _targetFractions(int count) {
    if (count <= 1) {
      return const [0.5];
    }
    if (count == 2) {
      return const [0.32, 0.68];
    }
    final step = 0.52 / (count - 1);
    return List<double>.generate(count, (index) => 0.24 + (step * index));
  }
}

class _SkeletonCalloutCard extends StatelessWidget {
  const _SkeletonCalloutCard({required this.callout});

  final SkeletonCallout callout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: callout.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: callout.color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  callout.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: callout.color,
                  ),
                ),
              ),
              if (callout.showAiTag)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: callout.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: callout.color.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            callout.value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: callout.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  const _SkeletonPainter({
    required this.callouts,
    required this.cardLeftFactor,
    required this.targetFractions,
  });

  final List<SkeletonCallout> callouts;
  final double cardLeftFactor;
  final List<double> targetFractions;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = VFTheme.jadeMid.withValues(alpha: 0.42)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final softPaint = Paint()
      ..color = VFTheme.jadeMid.withValues(alpha: 0.22)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final jointPaint = Paint()
      ..color = VFTheme.jade
      ..style = PaintingStyle.fill;
    final leaderPaint = Paint()
      ..color = VFTheme.textMuted.withValues(alpha: 0.35)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final groundY = size.height * 0.88;
    final head = Offset(size.width * 0.28, size.height * 0.18);
    final neck = Offset(size.width * 0.28, size.height * 0.28);
    final shoulder = Offset(size.width * 0.30, size.height * 0.34);
    final hip = Offset(size.width * 0.24, size.height * 0.56);
    final knee = Offset(size.width * 0.16, size.height * 0.72);
    final ankle = Offset(size.width * 0.20, size.height * 0.88);
    final foot = Offset(size.width * 0.11, groundY);
    final elbow = Offset(size.width * 0.34, size.height * 0.46);
    final wrist = Offset(size.width * 0.30, size.height * 0.58);

    canvas.drawLine(
      Offset(size.width * 0.06, groundY),
      Offset(size.width * 0.54, groundY),
      leaderPaint..color = VFTheme.textMuted.withValues(alpha: 0.24),
    );
    leaderPaint.color = VFTheme.textMuted.withValues(alpha: 0.35);

    canvas.drawCircle(
      head,
      size.width * 0.036,
      softPaint..style = PaintingStyle.stroke,
    );
    softPaint.style = PaintingStyle.stroke;
    canvas.drawLine(neck, shoulder, linePaint);
    canvas.drawLine(shoulder, hip, linePaint);
    canvas.drawLine(shoulder, elbow, softPaint);
    canvas.drawLine(elbow, wrist, softPaint);
    canvas.drawLine(hip, knee, linePaint);
    canvas.drawLine(knee, ankle, linePaint);
    canvas.drawLine(ankle, foot, softPaint);

    for (final joint in [shoulder, hip, knee, ankle]) {
      canvas.drawCircle(joint, 4.5, jointPaint);
    }

    _drawAngleArc(
      canvas,
      center: hip,
      radius: size.width * 0.08,
      startAngle: -0.9,
      sweepAngle: 0.68,
      color: VFTheme.amber,
    );
    _drawAngleArc(
      canvas,
      center: knee,
      radius: size.width * 0.07,
      startAngle: -0.16,
      sweepAngle: 0.98,
      color: VFTheme.jade,
    );

    for (var i = 0; i < callouts.length; i++) {
      final callout = callouts[i];
      final start = Offset(
          callout.anchor.dx * size.width, callout.anchor.dy * size.height);
      final endY = targetFractions[i] * size.height;
      final bend = Offset(size.width * 0.60, start.dy);
      final end = Offset(size.width * cardLeftFactor, endY);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(bend.dx, bend.dy)
        ..lineTo(bend.dx, end.dy)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, leaderPaint);
    }
  }

  void _drawAngleArc(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweepAngle,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter oldDelegate) {
    return oldDelegate.callouts != callouts ||
        oldDelegate.cardLeftFactor != cardLeftFactor ||
        oldDelegate.targetFractions != targetFractions;
  }
}
