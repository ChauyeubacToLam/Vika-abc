// MetricDiagrams — small geometric illustrations of what AI measures.
//
// Per-metric, scalable, exercise-agnostic. Each diagram is a pure
// geometric primitive (lines, arcs, bars) drawn with refined CAD-style
// hairlines, full-range context, tick marks, and a glowing yellow
// target zone. Reads like a spec-sheet illustration, not a generic icon.
//
// Three kinds cover every measurement Vika supports today and in the
// future:
//
//   • angle    — two segments meeting at a vertex; faint full-range
//                arc with target zone highlighted in yellow + tick
//                marks at quarter positions
//   • time     — horizontal timeline 0..max with tick marks; yellow
//                target zone segment + threshold tick; small clock dot
//   • position — vertical scale with ground line + hatch marks;
//                yellow target band + threshold tick

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

enum MetricKind { angle, time, position }

/// Detects metric kind from a value string.
MetricKind inferMetricKind(String value) {
  final v = value.toLowerCase();
  if (v.contains('°')) return MetricKind.angle;
  if (v.contains('giây') || v.contains(' s') || v.endsWith('s')) {
    return MetricKind.time;
  }
  if (v.contains('%') || v.contains('cm')) return MetricKind.position;
  return MetricKind.angle;
}

/// Detects which side of a threshold the target zone sits on.
int _detectZonePosition(String value) {
  if (value.contains('≥') || value.contains('>=')) return 1;
  if (value.contains('<') || value.contains('≤') || value.contains('<=')) {
    return -1;
  }
  return 0;
}

class MetricDiagram extends StatelessWidget {
  const MetricDiagram({
    super.key,
    required this.kind,
    required this.value,
    this.size = 80,
  });

  final MetricKind kind;
  final String value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: switch (kind) {
          MetricKind.angle => _AnglePainter(
              zonePos: _detectZonePosition(value),
              inkColor: c.ink,
              inkFaintColor: c.inkFaint,
              borderColor: c.border,
              yellowColor: c.yellow,
              surfaceColor: c.bg,
            ),
          MetricKind.time => _TimePainter(
              zonePos: _detectZonePosition(value),
              inkColor: c.ink,
              inkFaintColor: c.inkFaint,
              borderColor: c.border,
              yellowColor: c.yellow,
              surfaceColor: c.bg,
            ),
          MetricKind.position => _PositionPainter(
              zonePos: _detectZonePosition(value),
              inkColor: c.ink,
              inkFaintColor: c.inkFaint,
              borderColor: c.border,
              yellowColor: c.yellow,
              surfaceColor: c.bg,
            ),
        },
      ),
    );
  }
}

/// Shared base data for the three painters.
abstract class _DiagramPainterBase extends CustomPainter {
  _DiagramPainterBase({
    required this.zonePos,
    required this.inkColor,
    required this.inkFaintColor,
    required this.borderColor,
    required this.yellowColor,
    required this.surfaceColor,
  });

  final int zonePos;
  final Color inkColor;
  final Color inkFaintColor;
  final Color borderColor;
  final Color yellowColor;
  final Color surfaceColor;

  /// Draws the faint rounded-rectangle plate behind every diagram —
  /// gives them all a consistent CAD-blueprint card feel.
  void _drawBackplate(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.drawRRect(r, Paint()..color = surfaceColor);
    canvas.drawRRect(
      r.deflate(0.6),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ANGLE — two segments + faint full-range arc + target zone + ticks.
// ═══════════════════════════════════════════════════════════════

class _AnglePainter extends _DiagramPainterBase {
  _AnglePainter({
    required super.zonePos,
    required super.inkColor,
    required super.inkFaintColor,
    required super.borderColor,
    required super.yellowColor,
    required super.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackplate(canvas, size);

    // Vertex near bottom-left.
    final vertex = Offset(size.width * 0.30, size.height * 0.78);
    final armLen = math.min(size.width, size.height) * 0.62;

    // Two arms: up-arm and an angled right-arm based on zonePos.
    final rightAngleFromVertical = switch (zonePos) {
      1 => 32.0,
      -1 => 68.0,
      _ => 50.0,
    };
    final theta = rightAngleFromVertical * math.pi / 180;
    final upArm = Offset(vertex.dx, vertex.dy - armLen);
    final rightArm = Offset(
      vertex.dx + armLen * math.sin(theta),
      vertex.dy - armLen * math.cos(theta),
    );

    // ── Full-range faint arc (the entire possible angle space) ──
    final fullArcRadius = armLen * 0.40;
    final fullArcRect = Rect.fromCircle(center: vertex, radius: fullArcRadius);
    // Sweep from -π/2 (up) clockwise by π/2 (to horizontal right).
    canvas.drawArc(
      fullArcRect,
      -math.pi / 2,
      math.pi / 2,
      false,
      Paint()
        ..color = inkFaintColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Tick marks on the full-range arc at quarter positions.
    final tickPaint = Paint()
      ..color = inkFaintColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (final pct in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final a = -math.pi / 2 + pct * (math.pi / 2);
      final inner = Offset(
        vertex.dx + math.cos(a) * (fullArcRadius - 3),
        vertex.dy + math.sin(a) * (fullArcRadius - 3),
      );
      final outer = Offset(
        vertex.dx + math.cos(a) * (fullArcRadius + 3),
        vertex.dy + math.sin(a) * (fullArcRadius + 3),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    // ── Yellow target zone within the full arc ──
    // Symbolic zone: which quarter of the full arc the target sits in.
    final (zStart, zSweep) = switch (zonePos) {
      1 => (0.55, 0.35), // minimum — target is later/right portion
      -1 => (0.10, 0.30), // maximum — target is earlier portion
      _ => (0.30, 0.40), // range — center
    };
    final arcStart = -math.pi / 2 + zStart * (math.pi / 2);
    final arcSweep = zSweep * (math.pi / 2);
    // Soft halo.
    canvas.drawArc(
      fullArcRect,
      arcStart,
      arcSweep,
      false,
      Paint()
        ..color = yellowColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawArc(
      fullArcRect,
      arcStart,
      arcSweep,
      false,
      Paint()
        ..color = yellowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    // ── Two arms (the angle) ──
    final armPaint = Paint()
      ..color = inkColor.withValues(alpha: 0.88)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(vertex, upArm, armPaint);
    canvas.drawLine(vertex, rightArm, armPaint);

    // Endpoint dots.
    canvas.drawCircle(upArm, 3, Paint()..color = inkColor);
    canvas.drawCircle(rightArm, 3, Paint()..color = inkColor);

    // Vertex with yellow medallion.
    canvas.drawCircle(
      vertex,
      5.5,
      Paint()
        ..color = yellowColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(vertex, 4.5, Paint()..color = yellowColor);
    canvas.drawCircle(
      vertex,
      4.5,
      Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // ── "θ" label inside the corner — engineer convention ──
    _drawText(
      canvas,
      'θ',
      Offset(size.width * 0.86, size.height * 0.16),
      9.5,
      inkFaintColor,
      italic: true,
    );
  }

  @override
  bool shouldRepaint(covariant _AnglePainter old) =>
      old.zonePos != zonePos ||
      old.inkColor != inkColor ||
      old.yellowColor != yellowColor;
}

// ═══════════════════════════════════════════════════════════════
// TIME — horizontal timeline + tick marks + yellow zone + clock dot.
// ═══════════════════════════════════════════════════════════════

class _TimePainter extends _DiagramPainterBase {
  _TimePainter({
    required super.zonePos,
    required super.inkColor,
    required super.inkFaintColor,
    required super.borderColor,
    required super.yellowColor,
    required super.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackplate(canvas, size);

    final padX = size.width * 0.14;
    final centerY = size.height * 0.55;
    final trackLeft = padX;
    final trackRight = size.width - padX;
    final trackWidth = trackRight - trackLeft;

    // ── Tick scale ABOVE the track (subtle) ──
    final tickPaint = Paint()
      ..color = inkFaintColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (final pct in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final x = trackLeft + pct * trackWidth;
      final h = pct == 0.0 || pct == 1.0 ? 7.0 : 5.0;
      canvas.drawLine(
        Offset(x, centerY - 10 - h),
        Offset(x, centerY - 10),
        tickPaint,
      );
    }

    // ── Main track ──
    canvas.drawLine(
      Offset(trackLeft, centerY),
      Offset(trackRight, centerY),
      Paint()
        ..color = inkFaintColor.withValues(alpha: 0.55)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    // ── Yellow target zone ──
    final (zoneStart, zoneEnd) = switch (zonePos) {
      1 => (0.50, 0.95),
      -1 => (0.05, 0.50),
      _ => (0.28, 0.72),
    };
    final zoneL = trackLeft + zoneStart * trackWidth;
    final zoneR = trackLeft + zoneEnd * trackWidth;
    // Halo glow.
    canvas.drawLine(
      Offset(zoneL, centerY),
      Offset(zoneR, centerY),
      Paint()
        ..color = yellowColor.withValues(alpha: 0.32)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      Offset(zoneL, centerY),
      Offset(zoneR, centerY),
      Paint()
        ..color = yellowColor
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );

    // ── Threshold marker ──
    final markerX = switch (zonePos) {
      1 => zoneL,
      -1 => zoneR,
      _ => (zoneL + zoneR) / 2,
    };
    canvas.drawLine(
      Offset(markerX, centerY - 9),
      Offset(markerX, centerY + 9),
      Paint()
        ..color = inkColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // ── End caps on the track ──
    final capPaint = Paint()..color = inkColor;
    canvas.drawCircle(Offset(trackLeft, centerY), 3, capPaint);
    canvas.drawCircle(Offset(trackRight, centerY), 3, capPaint);

    // ── Small clock glyph at bottom-left (context cue) ──
    final clockCenter = Offset(padX + 2, size.height - padX);
    canvas.drawCircle(
      clockCenter,
      4.5,
      Paint()
        ..color = inkFaintColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      clockCenter,
      Offset(clockCenter.dx, clockCenter.dy - 3),
      Paint()
        ..color = inkFaintColor.withValues(alpha: 0.85)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      clockCenter,
      Offset(clockCenter.dx + 2.5, clockCenter.dy),
      Paint()
        ..color = inkFaintColor.withValues(alpha: 0.85)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // ── "t" label bottom-right ──
    _drawText(
      canvas,
      't',
      Offset(size.width - padX + 2, size.height - padX + 2),
      11,
      inkFaintColor,
      italic: true,
    );
  }

  @override
  bool shouldRepaint(covariant _TimePainter old) =>
      old.zonePos != zonePos ||
      old.inkColor != inkColor ||
      old.yellowColor != yellowColor;
}

// ═══════════════════════════════════════════════════════════════
// POSITION — vertical scale + ground + hatches + yellow target band.
// ═══════════════════════════════════════════════════════════════

class _PositionPainter extends _DiagramPainterBase {
  _PositionPainter({
    required super.zonePos,
    required super.inkColor,
    required super.inkFaintColor,
    required super.borderColor,
    required super.yellowColor,
    required super.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackplate(canvas, size);

    final padY = size.height * 0.14;
    final centerX = size.width * 0.42;
    final trackTop = padY;
    final trackBottom = size.height - padY - 4;
    final trackHeight = trackBottom - trackTop;

    // ── Tick scale to the right of the track ──
    final tickPaint = Paint()
      ..color = inkFaintColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (final pct in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = trackTop + pct * trackHeight;
      final w = pct == 0.0 || pct == 1.0 ? 7.0 : 5.0;
      canvas.drawLine(
        Offset(centerX + 10, y),
        Offset(centerX + 10 + w, y),
        tickPaint,
      );
    }

    // ── Main vertical track ──
    canvas.drawLine(
      Offset(centerX, trackTop),
      Offset(centerX, trackBottom),
      Paint()
        ..color = inkFaintColor.withValues(alpha: 0.55)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    // ── Yellow target zone ──
    final (zoneStart, zoneEnd) = switch (zonePos) {
      1 => (0.05, 0.45),
      -1 => (0.55, 0.95),
      _ => (0.30, 0.70),
    };
    final zoneT = trackTop + zoneStart * trackHeight;
    final zoneB = trackTop + zoneEnd * trackHeight;
    canvas.drawLine(
      Offset(centerX, zoneT),
      Offset(centerX, zoneB),
      Paint()
        ..color = yellowColor.withValues(alpha: 0.32)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      Offset(centerX, zoneT),
      Offset(centerX, zoneB),
      Paint()
        ..color = yellowColor
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );

    // ── Threshold marker ──
    final markerY = switch (zonePos) {
      1 => zoneB,
      -1 => zoneT,
      _ => (zoneT + zoneB) / 2,
    };
    canvas.drawLine(
      Offset(centerX - 8, markerY),
      Offset(centerX + 8, markerY),
      Paint()
        ..color = inkColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // ── End caps ──
    final capPaint = Paint()..color = inkColor;
    canvas.drawCircle(Offset(centerX, trackTop), 3, capPaint);
    canvas.drawCircle(Offset(centerX, trackBottom), 3, capPaint);

    // ── Ground line + hatching ──
    final groundY = size.height - padY + 4;
    canvas.drawLine(
      Offset(size.width * 0.10, groundY),
      Offset(size.width * 0.86, groundY),
      Paint()
        ..color = inkColor.withValues(alpha: 0.78)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    final hatch = Paint()
      ..color = inkFaintColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.0;
    for (var i = 0; i < 6; i++) {
      final x1 = size.width * 0.12 + i * (size.width * 0.12);
      canvas.drawLine(
        Offset(x1, groundY + 1.5),
        Offset(x1 + 5, groundY + 6),
        hatch,
      );
    }

    // ── "h" label top-right ──
    _drawText(
      canvas,
      'h',
      Offset(size.width - padY - 4, padY - 2),
      11,
      inkFaintColor,
      italic: true,
    );
  }

  @override
  bool shouldRepaint(covariant _PositionPainter old) =>
      old.zonePos != zonePos ||
      old.inkColor != inkColor ||
      old.yellowColor != yellowColor;
}

// ═══════════════════════════════════════════════════════════════
// Tiny text-label helper for the engineer-convention labels (θ, t, h).
// ═══════════════════════════════════════════════════════════════

void _drawText(
  Canvas canvas,
  String text,
  Offset center,
  double fontSize,
  Color color, {
  bool italic = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: -0.2,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(
    canvas,
    Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
  );
}
