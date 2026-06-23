// ScoreGaugeCard — the central score moment on the Progress tab.
// Circular arc gauge with a sweep-in animation on first build, the big
// italic AVERAGE / 100 for the period in the center, a trend-direction
// chip (arrow + short word) to the right, and the coach quote under a
// hairline divider opened with a stylized italic glyph.
//
// Reads like a premium dashboard moment (Whoop / Oura / Apple Fitness)
// while staying in Vika's editorial Ivory grammar.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/progress_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';
import 'period_tabs.dart';

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
    if (old.data.average != widget.data.average) {
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
              // The net-change story lives in the ĐƯỜNG TIẾN BỘ chart directly
              // below; the gauge headline is the period AVERAGE, so there is no
              // from→to bar here (it would conflict with an average).
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
                          'XU HƯỚNG',
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
          // Arc gauge — dominant left moment, filled to the period average.
          SizedBox(
            width: 216,
            height: 216,
            child: _ArcGauge(score: data.average, animation: animation),
          ),
          const SizedBox(width: 6),
          // Trend-direction chip on the right — or, below the baseline (no
          // direction yet), a quiet hint in its place so the score stands alone.
          Expanded(
            child: data.direction != FormTrendDirection.none
                ? _TrendChip(direction: data.direction)
                : const _GaugeHint(),
          ),
        ],
      ),
    );
  }
}

/// Shown in the delta slot when there's no baseline yet (< 3 sessions).
/// Keeps the gauge composed without fabricating a delta number.
class _GaugeHint extends StatelessWidget {
  const _GaugeHint();

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Text(
      'Thêm buổi để thấy tiến triển.',
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        height: 1.45,
        letterSpacing: -0.2,
        color: c.invInkSoft.withValues(alpha: 0.7),
      ),
    );
  }
}

/// Trend-direction chip for the gauge's right slot once a baseline exists: an
/// arrow + a short word for where the period's form is heading. Yellow (a
/// "stat" use of the reserved accent) when rising; a quiet neutral chip when
/// holding or easing — Vika stays encouraging, so a dip reads neutral, never
/// alarming red.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.direction});
  final FormTrendDirection direction;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final (IconData icon, String label, bool rising) = switch (direction) {
      FormTrendDirection.up => (Icons.arrow_upward_rounded, 'Đang lên', true),
      FormTrendDirection.down => (
          Icons.arrow_downward_rounded,
          'Đang xuống',
          false,
        ),
      // flat (and the gated-out none) both render the steady chip.
      _ => (Icons.trending_flat_rounded, 'Ổn định', false),
    };
    final fill = rising ? c.yellow : c.invInkSoft.withValues(alpha: 0.14);
    final fg = rising ? c.yellowInk : c.invInkSoft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            boxShadow: rising
                ? [
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.44),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.4,
                  height: 1.0,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'qua từng buổi',
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
