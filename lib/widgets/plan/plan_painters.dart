// CustomPainter implementations for the Premium Ivory Plan screen.
//
// Three painters live here:
//   • CoachMarkPainter   — yellow disc + ink stick figure (the “coach voice”
//                          glyph in card hairlines)
//   • FigureSkeletonPainter — large stick figure with yellow joint dots,
//                             used inside the Today hero card on Plan
//   • BodyDiagramPainter — small upper-body silhouette with optional
//                          yellow region overlay (used in WeekFocusCard)
//
// All translate the inline SVG <path>/<line>/<circle> from
// vika-main-app-ivory-v1.jsx 1:1 — same coordinates, just scaled to the
// Flutter canvas size at paint time.

import 'package:flutter/material.dart';

import '../../theme/vf_theme.dart';

// ─── CoachMark ──────────────────────────────────────────────────────────────
// Yellow disc with a stick figure inside. Used as a tiny “the coach is
// speaking” mark next to the “HUẤN LUYỆN VIÊN GHI” eyebrow.
class CoachMarkPainter extends CustomPainter {
  const CoachMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 18;
    Offset p(double x, double y) => Offset(x * scale, y * scale);

    // Yellow disc with thin ink stroke.
    canvas.drawCircle(
      p(9, 9),
      8.5 * scale,
      Paint()..color = VikaIvoryMain.yellow,
    );
    canvas.drawCircle(
      p(9, 9),
      8.5 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * scale
        ..color = VikaIvoryMain.ink,
    );

    // Stick figure on top.
    final ink = Paint()
      ..color = VikaIvoryMain.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * scale
      ..strokeCap = StrokeCap.round;

    // Head.
    canvas.drawCircle(
        p(9, 5.5), 1.1 * scale, Paint()..color = VikaIvoryMain.ink);
    // Body.
    canvas.drawLine(p(9, 6.6), p(9, 10), ink);
    // Arms (single horizontal line).
    canvas.drawLine(p(6.5, 8), p(11.5, 8), ink);
    // Legs (V shape).
    canvas.drawLine(p(9, 10), p(7.5, 13), ink);
    canvas.drawLine(p(9, 10), p(10.5, 13), ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── FigureSkeleton ─────────────────────────────────────────────────────────
// The decorative stick figure that sits in the bottom-right of the Today
// hero card. Intentionally a wireframe — represents AI pose tracking, NOT
// a body silhouette. Yellow joint dots, faint outer body shape.
//
// Canvas viewBox: 120x200 in JSX. We scale to whatever box the widget gives.
class FigureSkeletonPainter extends CustomPainter {
  const FigureSkeletonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 120;
    final sy = size.height / 200;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    // Radial yellow glow behind the figure.
    final glowRect = Rect.fromCircle(center: p(60, 80), radius: 80 * sx);
    canvas.drawCircle(
      p(60, 80),
      80 * sx,
      Paint()
        ..shader = RadialGradient(
          colors: [
            VikaIvoryMain.yellow.withValues(alpha: 0.18),
            VikaIvoryMain.yellow.withValues(alpha: 0),
          ],
        ).createShader(glowRect),
    );

    // Faint outer body silhouette path (just to suggest a body, not show it).
    final body = Path()
      ..moveTo(60 * sx, 18 * sy)
      ..relativeCubicTo(-7 * sx, 0, -12 * sx, 5 * sy, -12 * sx, 12 * sy)
      ..relativeCubicTo(0, 6 * sy, 4 * sx, 11 * sy, 10 * sx, 12 * sy)
      ..relativeLineTo(0, 8 * sy)
      ..relativeLineTo(-12 * sx, 6 * sy)
      ..relativeCubicTo(-4 * sx, 2 * sy, -6 * sx, 6 * sy, -6 * sx, 10 * sy)
      ..relativeLineTo(0, 22 * sy)
      ..relativeCubicTo(0, 3 * sy, 2 * sx, 6 * sy, 5 * sx, 7 * sy)
      ..relativeLineTo(8 * sx, 2 * sy)
      ..relativeLineTo(-2 * sx, 30 * sy)
      ..relativeCubicTo(0, 5 * sy, 4 * sx, 9 * sy, 9 * sx, 9 * sy)
      ..relativeCubicTo(5 * sx, 0, 9 * sx, -4 * sy, 9 * sx, -9 * sy)
      ..relativeLineTo(-2 * sx, -30 * sy)
      ..relativeLineTo(8 * sx, -2 * sy)
      ..relativeCubicTo(3 * sx, -1 * sy, 5 * sx, -4 * sy, 5 * sx, -7 * sy)
      ..close();

    canvas.drawPath(
      body,
      Paint()..color = VikaIvoryMain.invInk.withValues(alpha: 0.10),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = VikaIvoryMain.invInk.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 * sx,
    );

    // Skeleton lines — bones, in yellow at varying opacities.
    final boneStrong = Paint()
      ..color = VikaIvoryMain.yellow.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * sx
      ..strokeCap = StrokeCap.round;

    final boneSoft = Paint()
      ..color = VikaIvoryMain.yellow.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * sx
      ..strokeCap = StrokeCap.round;

    // Spine.
    canvas.drawLine(p(60, 32), p(60, 100), boneStrong);
    // Shoulders.
    canvas.drawLine(p(44, 50), p(76, 50), boneStrong);
    // Hips.
    canvas.drawLine(p(48, 100), p(72, 100), boneStrong);

    // Arms (left + right, with elbows).
    canvas.drawLine(p(44, 50), p(38, 80), boneSoft);
    canvas.drawLine(p(38, 80), p(40, 100), boneSoft);
    canvas.drawLine(p(76, 50), p(82, 80), boneSoft);
    canvas.drawLine(p(82, 80), p(80, 100), boneSoft);

    // Legs (with knees).
    canvas.drawLine(p(48, 100), p(44, 138), boneStrong);
    canvas.drawLine(p(44, 138), p(46, 178), boneStrong);
    canvas.drawLine(p(72, 100), p(76, 138), boneStrong);
    canvas.drawLine(p(76, 138), p(74, 178), boneStrong);

    // Joint dots — yellow filled circles at every articulation.
    const joints = [
      [60.0, 24.0],
      [44.0, 50.0],
      [76.0, 50.0],
      [60.0, 70.0],
      [48.0, 100.0],
      [72.0, 100.0],
      [38.0, 80.0],
      [82.0, 80.0],
      [40.0, 100.0],
      [80.0, 100.0],
      [44.0, 138.0],
      [76.0, 138.0],
      [46.0, 178.0],
      [74.0, 178.0],
    ];
    final jointPaint = Paint()..color = VikaIvoryMain.yellow;
    for (final j in joints) {
      canvas.drawCircle(p(j[0], j[1]), 2.4 * sx, jointPaint);
    }

    // Knee “focus rings” — the dashed circles around both knees in JSX.
    final ringPaint = Paint()
      ..color = VikaIvoryMain.yellow.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * sx;
    _dashedCircle(canvas, p(44, 138), 6 * sx, ringPaint,
        dashLen: 2 * sx, gapLen: 2 * sx);
    _dashedCircle(canvas, p(76, 138), 6 * sx, ringPaint,
        dashLen: 2 * sx, gapLen: 2 * sx);
  }

  // Tiny helper to draw a dashed circle (Flutter has no built-in path dash).
  void _dashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required double dashLen,
    required double gapLen,
  }) {
    final circumference = 2 * 3.141592653589793 * radius;
    final step = (dashLen + gapLen);
    if (step <= 0) return;
    final dashAngle = (dashLen / circumference) * 2 * 3.141592653589793;
    final stepAngle = (step / circumference) * 2 * 3.141592653589793;
    var theta = -3.141592653589793 / 2;
    while (theta < (-3.141592653589793 / 2) + 2 * 3.141592653589793) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, theta, dashAngle, false, paint);
      theta += stepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── BodyDiagram ────────────────────────────────────────────────────────────
// Small upper-body silhouette (head + torso + arms + legs) used inside
// WeekFocusCard. When `region == hip`, a yellow dashed ring + filled dot
// overlay highlights the hip area.
class BodyDiagramPainter extends CustomPainter {
  const BodyDiagramPainter({required this.highlightHip});

  final bool highlightHip;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 56;
    final sy = size.height / 80;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * sx
      ..strokeCap = StrokeCap.round
      ..color = VikaIvoryMain.invInkSoft;

    // Head.
    canvas.drawCircle(p(28, 12), 6 * sx, stroke);
    // Body trunk.
    canvas.drawLine(p(28, 18), p(28, 36), stroke);
    // Arms outwards (mid-torso to hands).
    canvas.drawLine(p(28, 36), p(20, 48), stroke);
    canvas.drawLine(p(28, 36), p(36, 48), stroke);
    // Legs.
    canvas.drawLine(p(20, 48), p(18, 64), stroke);
    canvas.drawLine(p(36, 48), p(38, 64), stroke);

    if (highlightHip) {
      // Dashed ring around the hip area.
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * sx
        ..color = VikaIvoryMain.yellow.withValues(alpha: 0.7);
      _dashedCircle(canvas, p(28, 36), 11 * sx, ringPaint,
          dashLen: 2 * sx, gapLen: 3 * sx);
      // Filled hip dot.
      canvas.drawCircle(
          p(28, 36), 3 * sx, Paint()..color = VikaIvoryMain.yellow);
    }
  }

  void _dashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required double dashLen,
    required double gapLen,
  }) {
    final circumference = 2 * 3.141592653589793 * radius;
    final step = dashLen + gapLen;
    if (step <= 0) return;
    final dashAngle = (dashLen / circumference) * 2 * 3.141592653589793;
    final stepAngle = (step / circumference) * 2 * 3.141592653589793;
    var theta = -3.141592653589793 / 2;
    while (theta < (-3.141592653589793 / 2) + 2 * 3.141592653589793) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, theta, dashAngle, false, paint);
      theta += stepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant BodyDiagramPainter oldDelegate) =>
      oldDelegate.highlightHip != highlightHip;
}
