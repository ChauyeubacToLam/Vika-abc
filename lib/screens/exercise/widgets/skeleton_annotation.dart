// ExerciseAnatomyDiagram (was SkeletonAnnotation) — refined anatomical
// figure with numbered measurement markers, drawn in Vika's editorial
// Ivory palette. Reads like an engineering blueprint of where the AI
// is looking, not a kid's stick figure.
//
// Two postures supported so this template works for any exercise:
//   • SkeletonPosture.standing     — side-view, squat-bottom pose
//   • SkeletonPosture.lyingFaceUp  — supine, knees bent (Glute Bridge)
//   • SkeletonPosture.lyingFaceDown — prone, forearm plank (Plank)
//
// Visual grammar:
//   ▸ Faint hairline grid background (5% alpha) — blueprint vibe
//   ▸ Body rendered as outline strokes (1.5px ink, ~0.7 alpha)
//   ▸ Yellow joint dots with soft halos
//   ▸ Yellow angle arcs at measurement points
//   ▸ Numbered markers on body — small cream pills with italic numerals,
//     hairline ink border, drop shadow
//   ▸ Compact temporal-metric chips floating in the upper corner
//     (for metrics without an anatomical anchor, e.g. descent tempo,
//      bottom hold)
//
// Backward-compat: the old `SkeletonAnnotation` + `SkeletonCallout`
// classes are kept so the experience screen doesn't need to be
// rewritten — they now produce numbered markers internally.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/vf_theme.dart';

/// Which posture to draw — controls the body outline.
enum SkeletonPosture {
  /// Standing side view (e.g. Squat, Lunge).
  standing,

  /// Lying face-up with knees bent (e.g. Glute Bridge, McGill Curl-up).
  lyingFaceUp,

  /// Lying face-down (e.g. Plank, Push-up).
  lyingFaceDown,
}

/// A numbered measurement marker that pins to a point on the body.
@immutable
class SkeletonMarker {
  const SkeletonMarker({
    required this.number,
    required this.anchor,
    required this.label,
  });

  /// 1-based number rendered inside the marker.
  final int number;

  /// Normalized 0..1 position on the diagram area.
  final Offset anchor;

  /// Short label (e.g. "ĐỘ SÂU GỐI"). Stays inside the marker tooltip
  /// area for screen readers; not rendered as visible text on the body.
  final String label;
}

/// A temporal metric chip — for measurements that don't have a body
/// anchor (descent tempo, bottom hold). Renders as a small floating
/// label in the diagram corner.
@immutable
class SkeletonTempoChip {
  const SkeletonTempoChip({
    required this.number,
    required this.label,
    required this.value,
    required this.icon,
  });
  final int number;
  final String label; // "NHỊP XUỐNG"
  final String value; // "≥ 2.5s"
  final IconData icon;
}

// ═══════════════════════════════════════════════════════════════
// BACKWARD-COMPAT CALLOUT TYPE — kept so the experience screen
// doesn't need to change. Each callout becomes a numbered marker.
// ═══════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════
// PUBLIC WIDGET — drop-in replacement for the old SkeletonAnnotation.
// ═══════════════════════════════════════════════════════════════

class SkeletonAnnotation extends StatelessWidget {
  const SkeletonAnnotation({
    super.key,
    required this.callouts,
    this.posture = SkeletonPosture.standing,
    this.tempoChips = const [],
  });

  /// Anatomical callouts — each becomes a numbered on-body marker.
  /// Number order follows the list order, starting at 1.
  final List<SkeletonCallout> callouts;

  final SkeletonPosture posture;

  /// Temporal chips for metrics without anatomy anchors.
  final List<SkeletonTempoChip> tempoChips;

  @override
  Widget build(BuildContext context) {
    final markers = <SkeletonMarker>[
      for (var i = 0; i < callouts.length; i++)
        SkeletonMarker(
          number: i + 1,
          anchor: callouts[i].anchor,
          label: callouts[i].title,
        ),
    ];
    return ExerciseAnatomyDiagram(
      markers: markers,
      tempoChips: tempoChips,
      posture: posture,
    );
  }
}

/// Cleaner forward-facing API. Use this in new code; the
/// [SkeletonAnnotation] wrapper exists for backward compatibility.
class ExerciseAnatomyDiagram extends StatelessWidget {
  const ExerciseAnatomyDiagram({
    super.key,
    required this.markers,
    this.posture = SkeletonPosture.standing,
    this.tempoChips = const [],
    this.aspectRatio = 1.05,
  });

  final List<SkeletonMarker> markers;
  final SkeletonPosture posture;
  final List<SkeletonTempoChip> tempoChips;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Hairline grid background — blueprint vibe.
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(
                    color: c.ink.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Body anatomy + joints.
              Positioned.fill(
                child: CustomPaint(
                  painter: _AnatomyPainter(
                    posture: posture,
                    inkColor: c.ink,
                    inkSoftColor: c.inkSoft,
                    inkFaintColor: c.inkFaint,
                    yellowColor: c.yellow,
                  ),
                ),
              ),
              // Numbered markers on body — small floating pills.
              for (final m in markers)
                _MarkerPin(
                  marker: m,
                  parentWidth: constraints.maxWidth,
                  parentHeight: constraints.maxHeight,
                ),
              // Tempo chips in the upper-right corner.
              if (tempoChips.isNotEmpty)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < tempoChips.length; i++) ...[
                        _TempoChipWidget(chip: tempoChips[i]),
                        if (i < tempoChips.length - 1)
                          const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MARKER PIN — small numbered cream pill on the body.
// ═══════════════════════════════════════════════════════════════

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({
    required this.marker,
    required this.parentWidth,
    required this.parentHeight,
  });
  final SkeletonMarker marker;
  final double parentWidth;
  final double parentHeight;

  static const _diameter = 26.0;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final left = marker.anchor.dx * parentWidth - _diameter / 2;
    final top = marker.anchor.dy * parentHeight - _diameter / 2;
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: _diameter,
        height: _diameter,
        decoration: BoxDecoration(
          color: c.yellow,
          shape: BoxShape.circle,
          border: Border.all(color: c.ink, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: c.yellow.withValues(alpha: 0.36),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: c.ink.withValues(alpha: 0.18),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          marker.number.toString().padLeft(2, '0'),
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.4,
            height: 1.0,
            color: c.yellowInk,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TEMPO CHIP — small floating label for time-based metrics.
// ═══════════════════════════════════════════════════════════════

class _TempoChipWidget extends StatelessWidget {
  const _TempoChipWidget({required this.chip});
  final SkeletonTempoChip chip;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.borderHi),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: c.ink,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              chip.number.toString().padLeft(2, '0'),
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 8,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.3,
                height: 1.0,
                color: c.yellow,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(chip.icon, size: 12, color: c.inkSoft),
          const SizedBox(width: 5),
          Text(
            chip.label,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: c.inkSoft,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            chip.value,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.2,
              color: c.ink,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GRID BACKGROUND — faint hairline blueprint grid.
// ═══════════════════════════════════════════════════════════════

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const step = 24.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════
// ANATOMY PAINTER — outline figure based on posture.
// ═══════════════════════════════════════════════════════════════

class _AnatomyPainter extends CustomPainter {
  _AnatomyPainter({
    required this.posture,
    required this.inkColor,
    required this.inkSoftColor,
    required this.inkFaintColor,
    required this.yellowColor,
  });

  final SkeletonPosture posture;
  final Color inkColor;
  final Color inkSoftColor;
  final Color inkFaintColor;
  final Color yellowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()
      ..color = inkColor.withValues(alpha: 0.78)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final softLimb = Paint()
      ..color = inkSoftColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final jointFill = Paint()..color = yellowColor;
    final jointHalo = Paint()
      ..color = yellowColor.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final ground = Paint()
      ..color = inkFaintColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;

    switch (posture) {
      case SkeletonPosture.standing:
        _drawStanding(
            canvas, size, body, softLimb, jointFill, jointHalo, ground);
        break;
      case SkeletonPosture.lyingFaceUp:
        _drawLyingFaceUp(
            canvas, size, body, softLimb, jointFill, jointHalo, ground);
        break;
      case SkeletonPosture.lyingFaceDown:
        _drawLyingFaceDown(
            canvas, size, body, softLimb, jointFill, jointHalo, ground);
        break;
    }
  }

  // ────────────────────────────────────────────────────────
  // Standing — side-view squat at the bottom of the rep.
  // ────────────────────────────────────────────────────────
  void _drawStanding(
    Canvas canvas,
    Size size,
    Paint body,
    Paint softLimb,
    Paint jointFill,
    Paint jointHalo,
    Paint ground,
  ) {
    // Normalized to 0..1 of the diagram, then converted to px.
    Offset p(double x, double y) => Offset(x * size.width, y * size.height);
    final groundY = size.height * 0.86;

    final head = p(0.32, 0.20);
    final neck = p(0.32, 0.28);
    final shoulder = p(0.30, 0.34);
    final hip = p(0.22, 0.54);
    final knee = p(0.38, 0.66);
    final ankle = p(0.22, 0.84);
    final toe = p(0.36, 0.86);
    final heel = p(0.10, 0.86);
    final elbow = p(0.48, 0.44);
    final wrist = p(0.60, 0.48);

    // Ground.
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      ground,
    );
    // Tick marks under the foot — engineering blueprint feel.
    final tick = Paint()
      ..color = inkFaintColor.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawLine(
        Offset(x, groundY + 2),
        Offset(x + 6, groundY + 6),
        tick,
      );
    }

    // Head — outline circle.
    canvas.drawCircle(
      head,
      size.width * 0.042,
      Paint()
        ..color = inkColor.withValues(alpha: 0.78)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Spine + torso.
    canvas.drawLine(neck, shoulder, body);
    canvas.drawLine(shoulder, hip, body);

    // Arms — forward extended for balance.
    canvas.drawLine(shoulder, elbow, softLimb);
    canvas.drawLine(elbow, wrist, softLimb);

    // Legs.
    canvas.drawLine(hip, knee, body);
    canvas.drawLine(knee, ankle, body);
    // Foot — heel + toe with horizontal sole.
    canvas.drawLine(heel, toe, body);
    canvas.drawLine(ankle, heel, softLimb);
    canvas.drawLine(ankle, toe, softLimb);

    // Angle arcs at key joints — visual hints of what AI measures.
    _arc(canvas, hip, size.width * 0.075, -0.9, 0.7);
    _arc(canvas, knee, size.width * 0.07, -0.16, 0.98);

    // Yellow joint dots with soft halos.
    for (final j in [shoulder, hip, knee, ankle]) {
      canvas.drawCircle(j, 7, jointHalo);
      canvas.drawCircle(j, 4, jointFill);
    }
  }

  // ────────────────────────────────────────────────────────
  // Lying face-up — Glute Bridge / McGill Curl-up pose.
  // ────────────────────────────────────────────────────────
  void _drawLyingFaceUp(
    Canvas canvas,
    Size size,
    Paint body,
    Paint softLimb,
    Paint jointFill,
    Paint jointHalo,
    Paint ground,
  ) {
    Offset p(double x, double y) => Offset(x * size.width, y * size.height);
    final groundY = size.height * 0.74;

    final head = p(0.16, 0.55);
    final neck = p(0.22, 0.56);
    final shoulder = p(0.28, 0.62);
    final hip = p(0.54, 0.50); // lifted (bridge position)
    final knee = p(0.70, 0.40); // knees up
    final ankle = p(0.78, 0.70);
    final toe = p(0.86, 0.70);
    final elbow = p(0.22, 0.74);
    final wrist = p(0.16, 0.74);

    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      ground,
    );
    // Ground tick marks.
    final tick = Paint()
      ..color = inkFaintColor.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawLine(
        Offset(x, groundY + 2),
        Offset(x + 6, groundY + 6),
        tick,
      );
    }

    // Head outline.
    canvas.drawCircle(
      head,
      size.width * 0.042,
      Paint()
        ..color = inkColor.withValues(alpha: 0.78)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Spine arched up for bridge.
    final spinePath = Path()
      ..moveTo(neck.dx, neck.dy)
      ..quadraticBezierTo(
        (shoulder.dx + hip.dx) / 2,
        hip.dy - 8, // slight up-arc
        hip.dx,
        hip.dy,
      );
    canvas.drawPath(spinePath, body);

    // Arms flat at sides.
    canvas.drawLine(shoulder, elbow, softLimb);
    canvas.drawLine(elbow, wrist, softLimb);

    // Legs bent.
    canvas.drawLine(hip, knee, body);
    canvas.drawLine(knee, ankle, body);
    canvas.drawLine(ankle, toe, softLimb);

    _arc(canvas, hip, size.width * 0.075, -1.6, 1.0);
    _arc(canvas, knee, size.width * 0.07, 1.0, 1.0);

    for (final j in [shoulder, hip, knee, ankle]) {
      canvas.drawCircle(j, 7, jointHalo);
      canvas.drawCircle(j, 4, jointFill);
    }
  }

  // ────────────────────────────────────────────────────────
  // Lying face-down — forearm Plank.
  // ────────────────────────────────────────────────────────
  void _drawLyingFaceDown(
    Canvas canvas,
    Size size,
    Paint body,
    Paint softLimb,
    Paint jointFill,
    Paint jointHalo,
    Paint ground,
  ) {
    Offset p(double x, double y) => Offset(x * size.width, y * size.height);
    final groundY = size.height * 0.74;

    final head = p(0.16, 0.46);
    final neck = p(0.22, 0.50);
    final shoulder = p(0.28, 0.50);
    final hip = p(0.62, 0.50);
    final knee = p(0.78, 0.58);
    final ankle = p(0.92, 0.66);
    final toe = p(0.96, 0.70);
    final elbow = p(0.24, 0.66);
    final wrist = p(0.32, 0.72);

    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      ground,
    );
    final tick = Paint()
      ..color = inkFaintColor.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawLine(
        Offset(x, groundY + 2),
        Offset(x + 6, groundY + 6),
        tick,
      );
    }

    canvas.drawCircle(
      head,
      size.width * 0.042,
      Paint()
        ..color = inkColor.withValues(alpha: 0.78)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Body line — should be straight (that's the metric).
    canvas.drawLine(neck, shoulder, body);
    canvas.drawLine(shoulder, hip, body);
    canvas.drawLine(hip, knee, body);
    canvas.drawLine(knee, ankle, body);
    canvas.drawLine(ankle, toe, softLimb);

    // Forearm support.
    canvas.drawLine(shoulder, elbow, softLimb);
    canvas.drawLine(elbow, wrist, softLimb);

    _arc(canvas, hip, size.width * 0.075, -2.4, 0.6);

    for (final j in [shoulder, hip, knee, ankle, elbow]) {
      canvas.drawCircle(j, 7, jointHalo);
      canvas.drawCircle(j, 4, jointFill);
    }
  }

  void _arc(
    Canvas canvas,
    Offset center,
    double radius,
    double startRad,
    double sweepRad,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      startRad,
      sweepRad,
      false,
      Paint()
        ..color = yellowColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _AnatomyPainter old) =>
      old.posture != posture ||
      old.inkColor != inkColor ||
      old.yellowColor != yellowColor;
}

// Suppress unused-import warning for math (used in earlier revisions
// of the curve helpers). Tiny no-op constant.
// ignore: unused_element
const _piTwo = math.pi * 2;
