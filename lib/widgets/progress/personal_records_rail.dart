// PersonalRecordsRail — horizontal rail of PR cards. The "+14 form
// score" tells *how much you've improved overall*; this section tells
// *which specific records you've just broken*. Reads like a sports
// paper's PR sidebar — the kind of moments people screenshot.
//
// Each card carries an exercise name, the record value (e.g. "28
// giây"), how that compares to before ("trước: 18s"), a date stamp,
// and an optional yellow "MỚI" pulse on fresh PRs (set today).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

@immutable
class PersonalRecord {
  const PersonalRecord({
    required this.exercise,
    required this.value,
    required this.unit,
    required this.previous,
    required this.dateLabel,
    required this.icon,
    required this.isNew,
  });
  final String exercise;
  final String value;
  final String unit;
  final String previous;
  final String dateLabel;
  final IconData icon;

  /// When true, the card shows a pulsing yellow "MỚI" badge — used for
  /// PRs set inside the active period.
  final bool isNew;
}

class PersonalRecordsRail extends StatelessWidget {
  const PersonalRecordsRail({
    super.key,
    required this.records,
    this.cardWidth = 210,
    this.gutter = 20,
  });

  final List<PersonalRecord> records;
  final double cardWidth;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 0),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _RecordCard(
          record: records[i],
          width: cardWidth,
          index: i,
        ),
      ),
    );
  }
}

class _RecordCard extends StatefulWidget {
  const _RecordCard({
    required this.record,
    required this.width,
    required this.index,
  });
  final PersonalRecord record;
  final double width;
  final int index;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = widget.record;
    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.width,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.bgRaised,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: r.isNew ? c.yellow.withValues(alpha: 0.35) : c.border,
                width: r.isNew ? 1.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: r.isNew
                      ? c.yellow.withValues(alpha: 0.16)
                      : c.ink.withValues(alpha: 0.04),
                  blurRadius: r.isNew ? 18 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Yellow halo top-right (only if a new record).
                if (r.isNew)
                  Positioned(
                    top: -60,
                    right: -60,
                    child: IgnorePointer(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c.yellow.withValues(alpha: 0.34),
                              c.yellow.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Watermark italic numeral — slightly more visible.
                Positioned(
                  bottom: -28,
                  right: -12,
                  child: IgnorePointer(
                    child: Text(
                      (widget.index + 1).toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 132,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -6,
                        height: 1,
                        color: c.ink.withValues(alpha: 0.06),
                        fontFeatures: VikaIvoryMain.tabularFigures,
                      ),
                    ),
                  ),
                ),
                // Yellow vertical accent bar on the left edge of new
                // PRs — gives them a "marked" feel.
                if (r.isNew)
                  Positioned(
                    left: 0,
                    top: 18,
                    bottom: 18,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.yellowGhost,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              r.icon,
                              size: 16,
                              color: c.ink,
                            ),
                          ),
                          const Spacer(),
                          if (r.isNew) _NewBadge(yellow: c.yellow, ink: c.ink),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'KỶ LỤC · ${r.exercise.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: c.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                r.value,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -1.8,
                                  height: 0.95,
                                  color: c.ink,
                                  fontFeatures: VikaIvoryMain.tabularFigures,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              r.unit,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                                letterSpacing: -0.2,
                                color: c.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 22,
                        height: 2,
                        decoration: BoxDecoration(
                          color: c.yellow,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Trước: ${r.previous}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.inkFaint,
                          fontFeatures: VikaIvoryMain.tabularFigures,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 11,
                            color: c.inkFaint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            r.dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.1,
                              color: c.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Trophy celebration — only on new PRs. Shimmer sweep
                // + sparkle particles. Painted last so it floats above
                // the content; IgnorePointer keeps the card tappable.
                if (r.isNew)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                        child: _CelebrationOverlay(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NEW PR BADGE — static yellow pill with a sparkle icon.
// The "look at me" energy lives in the surrounding card celebration
// overlay (shimmer + sparkles), not in the badge itself bobbing.
// ═══════════════════════════════════════════════════════════════

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.yellow, required this.ink});
  final Color yellow;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: yellow,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: yellow.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 10, color: ink),
          const SizedBox(width: 5),
          Text(
            'MỚI',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CELEBRATION OVERLAY — the trophy moment.
//
// Three effects, one shared AnimationController:
//   1. A diagonal *foil shimmer* band sweeps across the card every
//      3.2 seconds — the same "holographic foil" feel Apple uses on
//      App Store achievement cards.
//   2. Three sparkle particles emit from staggered anchor points,
//      each scaling + rotating in and out during their own phase.
//   3. The icon medallion behind it picks up a soft pulsing halo.
//
// All composited with IgnorePointer so taps still hit the card body.
// ═══════════════════════════════════════════════════════════════

class _CelebrationOverlay extends StatefulWidget {
  const _CelebrationOverlay();

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// Sparkle scale curve: 0 → 1 → 0 over its phase window.
  /// Returns 0 outside the window so the sparkle is fully hidden.
  double _scaleAt(double t, double start, double end) {
    if (t < start || t > end) return 0;
    final phase = (t - start) / (end - start);
    return math.sin(phase * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _ctl,
          builder: (context, _) {
            final t = _ctl.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Shimmer sweep — full-card diagonal foil pass.
                CustomPaint(
                  painter: _ShimmerPainter(
                    progress: t,
                    shineColor: c.yellow,
                  ),
                ),
                // Sparkles at staggered phases.
                _sparkleAt(w * 0.86, h * 0.14, 11, t, 0.00, 0.36, c.yellow),
                _sparkleAt(w * 0.18, h * 0.58, 7, t, 0.28, 0.62, c.yellow),
                _sparkleAt(w * 0.74, h * 0.80, 13, t, 0.55, 0.96, c.yellow),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sparkleAt(
    double cx,
    double cy,
    double size,
    double t,
    double startPhase,
    double endPhase,
    Color color,
  ) {
    final scale = _scaleAt(t, startPhase, endPhase);
    if (scale <= 0.01) return const SizedBox.shrink();
    return Positioned(
      left: cx - size,
      top: cy - size,
      child: Transform.scale(
        scale: scale,
        child: Transform.rotate(
          angle: t * math.pi * 2,
          child: SizedBox.square(
            dimension: size * 2,
            child: CustomPaint(
              painter: _SparkleShape(
                color: color.withValues(alpha: 0.85 * scale),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({required this.progress, required this.shineColor});
  final double progress; // 0..1
  final Color shineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Diagonal band travels from outside-upper-left to outside-lower-right.
    final shineWidth = w * 0.55;
    final startX = -shineWidth - w * 0.6;
    final endX = w + shineWidth + w * 0.6;
    final centerX = startX + (endX - startX) * progress;

    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-math.pi / 7); // ~-25° diagonal
    canvas.translate(-w / 2, -h / 2);

    final rect = Rect.fromLTWH(
      centerX - shineWidth,
      -h,
      shineWidth * 2,
      h * 3,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          shineColor.withValues(alpha: 0),
          shineColor.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.38),
          shineColor.withValues(alpha: 0.18),
          shineColor.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.38, 0.5, 0.62, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) =>
      old.progress != progress || old.shineColor != shineColor;
}

class _SparkleShape extends CustomPainter {
  _SparkleShape({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.58, h * 0.42)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.58, h * 0.58)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.42, h * 0.58)
      ..lineTo(0, h * 0.5)
      ..lineTo(w * 0.42, h * 0.42)
      ..close();
    // Soft halo behind the star — gives the sparkle some glow.
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      w * 0.55,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkleShape old) => old.color != color;
}
