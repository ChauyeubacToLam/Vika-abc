// ScoreGaugeCard — the central score moment on the Progress tab.
// Circular arc gauge with a sweep-in animation on first build, big
// italic 74 / 100 in the center, an editorial "+14" badge to the
// right, refined from-to bar with tick marks, and the coach quote
// under a hairline divider opened with a stylized italic glyph.
//
// Reads like a premium dashboard moment (Whoop / Oura / Apple Fitness)
// while staying in Vika's editorial Ivory grammar.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/progress_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';

class ScoreGaugeCard extends StatefulWidget {
  const ScoreGaugeCard({super.key, required this.data});

  final HeadlineForPeriod data;

  @override
  State<ScoreGaugeCard> createState() => _ScoreGaugeCardState();
}

class _ScoreGaugeCardState extends State<ScoreGaugeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _t = CurvedAnimation(parent: _ctl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctl.forward());
  }

  @override
  void didUpdateWidget(covariant ScoreGaugeCard old) {
    super.didUpdateWidget(old);
    if (old.data.to != widget.data.to) {
      _ctl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.22),
            blurRadius: 44,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: c.ink.withValues(alpha: 0.10),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Yellow radial wash, top-right — atmospheric language
          // borrowed from the stage hero.
          Positioned(
            top: -90,
            right: -70,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.yellow.withValues(alpha: 0.24),
                      c.yellow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
            ),
          ),
          // Soft terracotta wash, bottom-left — warms the card.
          Positioned(
            bottom: -110,
            left: -90,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x33CD7C45), // 0.20 alpha
                      Color(0x00CD7C45),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EyebrowRow(label: widget.data.label),
              const SizedBox(height: 28),
              _GaugeBlock(data: widget.data, animation: _t),
              const SizedBox(height: 26),
              _FromToBar(from: widget.data.from, to: widget.data.to),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.only(top: 18),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.borderDark)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CoachMark(small: true),
                        const SizedBox(width: 10),
                        PlanEyebrow(
                          'HUẤN LUYỆN VIÊN GHI',
                          size: 9.5,
                          letterSpacing: 1.6,
                          dark: true,
                        ),
                        const Spacer(),
                        Text(
                          '“',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            height: 0.4,
                            color: c.yellow.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PlanP(
                      widget.data.coach,
                      dark: true,
                      italic: true,
                      size: 15,
                      letterSpacing: -0.2,
                      height: 1.5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EYEBROW
// ═══════════════════════════════════════════════════════════════

class _EyebrowRow extends StatelessWidget {
  const _EyebrowRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: c.yellow,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: c.yellow, blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'FORM CHUẨN TRUNG BÌNH',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: c.yellow,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: c.yellow.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: c.invInkSoft.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GAUGE — the central moment. Animated arc + score + delta badge.
// ═══════════════════════════════════════════════════════════════

class _GaugeBlock extends StatelessWidget {
  const _GaugeBlock({required this.data, required this.animation});
  final HeadlineForPeriod data;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 216,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Arc gauge — dominant left moment.
          SizedBox(
            width: 216,
            height: 216,
            child: _ArcGauge(score: data.to, animation: animation),
          ),
          const SizedBox(width: 6),
          // Delta + descriptor stacked on the right.
          Expanded(
            child: _DeltaBadge(delta: data.delta),
          ),
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta});
  final String delta;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The +14 chip — ink-filled, yellow text, with a tiny up arrow.
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
          decoration: BoxDecoration(
            color: c.yellow,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.44),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_upward_rounded,
                size: 14,
                color: c.yellowInk,
              ),
              const SizedBox(width: 2),
              Text(
                delta.replaceAll('+', ''),
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.0,
                  height: 1.0,
                  color: c.yellowInk,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'điểm form',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.3,
            color: c.invInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'từ điểm xuất phát',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: c.invInkSoft.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _ArcGauge extends StatelessWidget {
  const _ArcGauge({required this.score, required this.animation});
  final int score;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        // Animated score that ticks up as the arc sweeps in.
        final animatedScore = (score * t).round();
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ArcPainter(
                  score: score,
                  progress: t,
                  trackColor: c.invInk.withValues(alpha: 0.08),
                  fillColor: c.yellow,
                  tickColor: c.invInkSoft.withValues(alpha: 0.35),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                Text(
                  'ĐIỂM FORM',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: c.invInkSoft.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$animatedScore',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 84,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -4.0,
                    height: 0.92,
                    color: c.invInk,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 18,
                  height: 1.5,
                  color: c.yellow.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 6),
                Text(
                  '/ 100',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: c.invInkSoft.withValues(alpha: 0.5),
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.score,
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.tickColor,
  });

  final int score;
  final double progress; // 0..1 — entry sweep
  final Color trackColor;
  final Color fillColor;
  final Color tickColor;

  /// Arc spans from 8 o'clock to 4 o'clock — 280° sweep.
  static const _startDeg = 130.0;
  static const _sweepDeg = 280.0;

  double _deg2rad(double d) => d * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 16;
    const stroke = 13.0;

    // Track.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _deg2rad(_startDeg),
      _deg2rad(_sweepDeg),
      false,
      trackPaint,
    );

    // Filled segment — gated by both score and entry-sweep progress.
    final fullFillSweep = _sweepDeg * (score.clamp(0, 100) / 100);
    final fillSweep = fullFillSweep * progress;
    if (fillSweep > 0.01) {
      final fillPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: _deg2rad(_startDeg),
          endAngle: _deg2rad(_startDeg + _sweepDeg),
          colors: [
            fillColor.withValues(alpha: 0.55),
            fillColor,
            fillColor,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: radius),
        );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _deg2rad(_startDeg),
        _deg2rad(fillSweep),
        false,
        fillPaint,
      );

      // End-of-fill bright dot — like a clock hand tip.
      final tipAngle = _deg2rad(_startDeg + fillSweep);
      final tip = Offset(
        center.dx + math.cos(tipAngle) * radius,
        center.dy + math.sin(tipAngle) * radius,
      );
      // Soft glow.
      canvas.drawCircle(
        tip,
        stroke / 2 + 6,
        Paint()
          ..color = fillColor.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Bright core.
      canvas.drawCircle(
        tip,
        stroke / 2 + 2,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
      // Inner ink dot — gives the tip a "pin" feel.
      canvas.drawCircle(
        tip,
        2.5,
        Paint()
          ..color = trackColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
    }

    // Tick marks at 25 / 50 / 75 positions.
    for (final pct in const [0.25, 0.5, 0.75]) {
      final tickAngle = _deg2rad(_startDeg + _sweepDeg * pct);
      final tickInner = Offset(
        center.dx + math.cos(tickAngle) * (radius - stroke - 2),
        center.dy + math.sin(tickAngle) * (radius - stroke - 2),
      );
      final tickOuter = Offset(
        center.dx + math.cos(tickAngle) * (radius - stroke - 9),
        center.dy + math.sin(tickAngle) * (radius - stroke - 9),
      );
      canvas.drawLine(
        tickInner,
        tickOuter,
        Paint()
          ..color = tickColor
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.score != score ||
      old.progress != progress ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}

// ═══════════════════════════════════════════════════════════════
// FROM → TO BAR (refined: now with quartile tick marks)
// ═══════════════════════════════════════════════════════════════

class _FromToBar extends StatelessWidget {
  const _FromToBar({required this.from, required this.to});

  final int from;
  final int to;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                PlanEyebrow('BẮT ĐẦU', size: 9, letterSpacing: 1.4, dark: true),
                const SizedBox(width: 8),
                Text(
                  '$from',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: c.invInkSoft,
                    letterSpacing: -0.2,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '$to',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: c.invInk,
                    letterSpacing: -0.3,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
                const SizedBox(width: 8),
                PlanEyebrow('HÔM NAY', size: 9, letterSpacing: 1.4, dark: true),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 22,
          child: LayoutBuilder(
            builder: (context, bc) {
              final width = bc.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track.
                  Positioned(
                    top: 7,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.invInk.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Quartile tick marks above the track.
                  for (final pct in const [0.25, 0.5, 0.75])
                    Positioned(
                      top: 0,
                      left: pct * width - 0.5,
                      child: Container(
                        width: 1,
                        height: 5,
                        color: c.invInkSoft.withValues(alpha: 0.32),
                      ),
                    ),
                  // Yellow segment from→to.
                  Positioned(
                    top: 7,
                    left: (from / 100) * width,
                    width: ((to - from) / 100) * width,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            c.yellow.withValues(alpha: 0.35),
                            c.yellow,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Start dot.
                  Positioned(
                    top: 4,
                    left: (from / 100) * width - 7,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: c.bgInverse,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.invInk.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // Today dot.
                  Positioned(
                    top: 3,
                    left: (to / 100) * width - 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.bgInverse,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
