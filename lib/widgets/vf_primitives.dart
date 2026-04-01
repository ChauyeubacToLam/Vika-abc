import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/vf_theme.dart';

class VFGrainOverlay extends StatelessWidget {
  const VFGrainOverlay({
    super.key,
    this.opacity = 0.035,
  });

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _VFGrainPainter(opacity: opacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _VFGrainPainter extends CustomPainter {
  const _VFGrainPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final bright = Paint()..style = PaintingStyle.fill;
    final dark = Paint()..style = PaintingStyle.fill;

    for (double y = 0; y < size.height; y += 4) {
      for (double x = 0; x < size.width; x += 4) {
        final seed = _hash(x, y);
        if (seed > 0.68) {
          bright.color =
              Colors.white.withValues(alpha: opacity * (0.45 + seed * 0.55));
          canvas.drawRect(
            Rect.fromLTWH(x, y, 1 + (seed > 0.9 ? 1 : 0), 1),
            bright,
          );
        } else if (seed < 0.08) {
          dark.color =
              Colors.black.withValues(alpha: opacity * 0.32 * (1 - seed));
          canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), dark);
        }
      }
    }
  }

  double _hash(double x, double y) {
    final value = math.sin((x * 12.9898) + (y * 78.233)) * 43758.5453;
    return value - value.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _VFGrainPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

class VFGradientAvatar extends StatelessWidget {
  const VFGradientAvatar({
    super.key,
    required this.label,
    this.size = 44,
    this.fontSize = 17,
    this.fontWeight = FontWeight.w800,
  });

  final String label;
  final double size;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: VFTheme.jadeGradient,
        boxShadow: VFTheme.jadeShadow,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: VFTheme.textStyle(
          context,
          size: fontSize,
          weight: fontWeight,
          color: VFTheme.white,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

enum VFNavGlyph { home, plan, progress, profile, plus }

class VFNavIcon extends StatelessWidget {
  const VFNavIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.size = 20,
    this.strokeWidth = 1.6,
  });

  final VFNavGlyph glyph;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _VFNavPainter(
          glyph: glyph,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _VFNavPainter extends CustomPainter {
  const _VFNavPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
  });

  final VFNavGlyph glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 20;
    final sy = size.height / 20;
    canvas.scale(sx, sy);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (glyph) {
      case VFNavGlyph.home:
        final house = Path()
          ..moveTo(3, 9.5)
          ..lineTo(10, 3.5)
          ..lineTo(17, 9.5)
          ..lineTo(17, 18)
          ..arcToPoint(const Offset(16, 19), radius: const Radius.circular(1))
          ..lineTo(4, 19)
          ..arcToPoint(const Offset(3, 18), radius: const Radius.circular(1))
          ..close();
        canvas.drawPath(house, paint);
        break;
      case VFNavGlyph.plan:
        final body = Path()
          ..moveTo(4, 4)
          ..lineTo(16, 4)
          ..arcToPoint(const Offset(18, 6), radius: const Radius.circular(2))
          ..lineTo(18, 18)
          ..arcToPoint(const Offset(16, 20), radius: const Radius.circular(2))
          ..lineTo(4, 20)
          ..close();
        canvas.drawPath(body, paint);
        canvas.drawLine(const Offset(8, 2), const Offset(8, 6), paint);
        canvas.drawLine(const Offset(12, 2), const Offset(12, 6), paint);
        canvas.drawLine(const Offset(4, 10), const Offset(20, 10), paint);
        break;
      case VFNavGlyph.progress:
        final chart = Path()
          ..moveTo(3, 17)
          ..lineTo(7, 13)
          ..lineTo(11, 17)
          ..lineTo(17, 9)
          ..lineTo(21, 13);
        canvas.drawPath(chart, paint);
        break;
      case VFNavGlyph.profile:
        canvas.drawCircle(const Offset(10, 8), 4, paint);
        final shoulders = Path()
          ..moveTo(3, 20)
          ..quadraticBezierTo(10, 14, 17, 20);
        canvas.drawPath(shoulders, paint);
        break;
      case VFNavGlyph.plus:
        canvas.drawLine(const Offset(10, 4), const Offset(10, 18), paint);
        canvas.drawLine(const Offset(4, 11), const Offset(18, 11), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _VFNavPainter oldDelegate) {
    return oldDelegate.glyph != glyph ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
