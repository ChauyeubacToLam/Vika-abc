import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PhaseChevronStream — ambient, wordless "which way should I be moving".
//
// A faint chevron stream beside the body area (never over it): flowing
// downward during `descending`, upward during `ascending`, hidden otherwise.
// Deliberately quiet — visible when you look for it, ignorable when you
// don't. If this element ever competes with the hero elements, it is too
// loud.
//
// Transform-only: one repeating controller translates a fixed chevron
// pattern; the painter draws two lines per chevron and allocates nothing per
// frame beyond its Paint. Tempo is a single constant for now.
// TODO(tempo): couple _periodMs to the exercise's target tempo (later pass).
// ═══════════════════════════════════════════════════════════════════════════

/// Flow direction, mapped from the exercise's `currentPhaseKey` by the page.
enum ChevronFlow { down, up }

class PhaseChevronStream extends StatefulWidget {
  const PhaseChevronStream({super.key, required this.flow});

  final ChevronFlow flow;

  @override
  State<PhaseChevronStream> createState() => _PhaseChevronStreamState();
}

class _PhaseChevronStreamState extends State<PhaseChevronStream>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow;

  /// One full travel of the pattern. Fixed for now (see TODO above).
  static const int _periodMs = 1200;

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _periodMs),
    )..repeat();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          width: 34,
          height: 190,
          child: AnimatedBuilder(
            animation: _flow,
            builder: (context, _) {
              return CustomPaint(
                painter: _ChevronStreamPainter(
                  phase: _flow.value,
                  pointDown: widget.flow == ChevronFlow.down,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChevronStreamPainter extends CustomPainter {
  const _ChevronStreamPainter({required this.phase, required this.pointDown});

  final double phase;
  final bool pointDown;

  static const int _chevrons = 4;
  static const double _halfWidth = 12.0;
  static const double _depth = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    for (var i = 0; i < _chevrons; i++) {
      // Each chevron rides the loop offset by 1/N; travel direction follows
      // the flow, and the sin envelope fades it in and out at the ends so
      // the stream never pops.
      final local = (phase + i / _chevrons) % 1.0;
      final travel = pointDown ? local : 1.0 - local;
      final y = size.height * travel;
      final fade = math.sin(local * math.pi);
      // Low alpha on cream — ambient, never competing with the heroes.
      paint.color = VikaIvory.invInk.withValues(alpha: 0.26 * fade);
      final tip = pointDown ? y + _depth : y - _depth;
      canvas.drawLine(Offset(cx - _halfWidth, y), Offset(cx, tip), paint);
      canvas.drawLine(Offset(cx, tip), Offset(cx + _halfWidth, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChevronStreamPainter old) {
    return old.phase != phase || old.pointDown != pointDown;
  }
}
