// ProfileStageHero — v2 personal-first.
//
// Inspired by how Strava, Apple Fitness, and Whoop open a profile:
// the *avatar* is the hero, not the headline. The avatar gets a big
// circular medallion treatment with an arc wrapping it that shows the
// user's goal progress — so identity and journey are visually one
// thing, not two.
//
// Layout (centered):
//   ┌────────────────────────────────────────────┐
//   │ [wordmark]                  [⚙]            │
//   │                                             │
//   │             ╱ ─ ─ ─ ╲                      │
//   │            │ ┌────┐ │   ← yellow arc       │
//   │            │ │ N. │ │     wrapping avatar  │
//   │            │ └────┘ │                      │
//   │             ╲ _42_ ╱                       │
//   │            42% mục tiêu                    │
//   │                                             │
//   │            Nam Trần.                       │  ← one-line italic
//   │      ✨ PHASE 1 · TUẦN 3 / 7               │
//   │                                             │
//   │   ── 12 NGÀY · 8 BUỔI · 74% FORM ──        │  ← inline stat strip
//   │                                             │
//   │   [✏ Sửa hồ sơ]   [⤴ Chia sẻ]              │
//   └────────────────────────────────────────────┘
//
// One headline ("Nam Trần.") on one line — no broken compound.
// FittedBox keeps long names safe.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../plan/wordmark_header.dart';

class ProfileStageHero extends StatelessWidget {
  const ProfileStageHero({
    super.key,
    required this.name,
    required this.userInitial,
    this.phaseLabel,
    required this.memberSinceLine,
    required this.goalProgress,
    required this.inlineStats,
    this.avatarUrl,
    this.onSettingsTap,
    this.onAvatarTap,
    this.onEdit,
    this.onShare,
    this.onEditPhoto,
  });

  final String name;
  final String userInitial;
  final String? avatarUrl;

  /// Phase/week pill copy, e.g. "TUẦN 1 / 7". Null hides the pill (no active
  /// plan) so we never show a fake phase.
  final String? phaseLabel;

  /// Single italic line under the phase pill, e.g.
  /// "Thành viên từ 27 / 4 · chuỗi 1 tháng" (the streak clause is dropped when
  /// there's no active-week streak).
  final String memberSinceLine;

  /// 0..100. Used by the avatar arc.
  final int goalProgress;

  /// Compact uppercase stat strip, e.g.
  /// ["12 NGÀY", "8 BUỔI", "74% FORM"]. 2-4 entries.
  final List<String> inlineStats;

  final VoidCallback? onSettingsTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;
  final VoidCallback? onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(36),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.7, -1),
            end: const Alignment(0.7, 1),
            colors: [c.bgInverse, c.bgInverseHi],
          ),
          boxShadow: [
            BoxShadow(
              color: c.ink.withValues(alpha: 0.22),
              blurRadius: 48,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Atmosphere
            Positioned(
              top: -140,
              right: -120,
              child: IgnorePointer(
                child: _AmbientGlow(
                  size: const Size(440, 440),
                  color: c.yellow,
                  opacity: 0.20,
                ),
              ),
            ),
            Positioned(
              bottom: -200,
              left: -150,
              child: IgnorePointer(
                child: _AmbientGlow(
                  size: const Size(440, 380),
                  color: const Color(0xFFCD7C45),
                  opacity: 0.16,
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: _GrainTexture(opacity: 0.05),
              ),
            ),
            const Positioned(
              top: 180,
              right: 40,
              child: IgnorePointer(
                child: Opacity(opacity: 0.32, child: _Sparkle(size: 11)),
              ),
            ),
            const Positioned(
              top: 480,
              left: 28,
              child: IgnorePointer(
                child: Opacity(opacity: 0.22, child: _Sparkle(size: 9)),
              ),
            ),

            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LightStatusBar(),
                  WordmarkHeader(
                    inverted: true,
                    userInitial: userInitial,
                    avatarUrl: avatarUrl,
                    trailingIcon: Icons.tune_rounded,
                    trailingTooltip: 'Cài đặt',
                    onTrailingTap: onSettingsTap,
                    onAvatarTap: onAvatarTap,
                  ),
                  const SizedBox(height: 28),

                  // AVATAR CENTERPIECE — the personal hero moment.
                  Center(
                    child: _AvatarHero(
                      initial: userInitial,
                      avatarUrl: avatarUrl,
                      goalProgress: goalProgress,
                      onEditPhoto: onEditPhoto,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Name — one line, italic, centered.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$name.',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -2.4,
                            height: 1.0,
                            color: c.invInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Phase pill — centered. Hidden when there's no active plan.
                  if (phaseLabel != null) ...[
                    Center(child: _PhasePill(label: phaseLabel!)),
                    const SizedBox(height: 14),
                  ],

                  // Member-since italic — centered, narrow.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Center(
                      child: Text(
                        memberSinceLine,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          height: 1.45,
                          color: c.invInkSoft,
                        ),
                      ),
                    ),
                  ),
                  // Inline stat strip — short uppercase, divided by dots.
                  // Hidden entirely for a brand-new user (empty list) so we
                  // never show a "0 NGÀY" placeholder strip.
                  if (inlineStats.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _InlineStatsRow(items: inlineStats),
                  ],
                  const SizedBox(height: 24),

                  // Edit + share pill buttons, centered.
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeroPillButton(
                          icon: Icons.edit_outlined,
                          label: 'Sửa hồ sơ',
                          filled: true,
                          onTap: onEdit,
                        ),
                        const SizedBox(width: 10),
                        _HeroPillButton(
                          icon: Icons.ios_share_rounded,
                          label: 'Chia sẻ',
                          filled: false,
                          onTap: onShare,
                        ),
                      ],
                    ),
                  ),
                  // Canonical hero internal bottom padding — matches
                  // Library + Progress stage heroes.
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AVATAR HERO — circle medallion + goal-progress arc + edit pencil.
// ═══════════════════════════════════════════════════════════════

class _AvatarHero extends StatefulWidget {
  const _AvatarHero({
    required this.initial,
    required this.goalProgress,
    this.avatarUrl,
    this.onEditPhoto,
  });

  final String initial;
  final String? avatarUrl;
  final int goalProgress;
  final VoidCallback? onEditPhoto;

  @override
  State<_AvatarHero> createState() => _AvatarHeroState();
}

class _AvatarHeroState extends State<_AvatarHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arcCtl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _arcCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _t = CurvedAnimation(parent: _arcCtl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _arcCtl.forward());
  }

  @override
  void didUpdateWidget(covariant _AvatarHero old) {
    super.didUpdateWidget(old);
    if (old.goalProgress != widget.goalProgress) {
      _arcCtl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _arcCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft yellow halo behind the whole avatar — atmospheric.
          // Negative offsets extend the halo beyond the 160×160 stack;
          // the parent Stack has `clipBehavior: Clip.none` so it bleeds.
          Positioned(
            left: -30,
            right: -30,
            top: -30,
            bottom: -30,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.yellow.withValues(alpha: 0.24),
                      c.yellow.withValues(alpha: 0),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Animated goal-progress arc.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) => CustomPaint(
                painter: _AvatarArcPainter(
                  progress: widget.goalProgress,
                  sweepProgress: _t.value,
                  trackColor: c.invInk.withValues(alpha: 0.10),
                  fillColor: c.yellow,
                ),
              ),
            ),
          ),
          // Avatar medallion.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: GestureDetector(
                onTap: widget.onEditPhoto,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        c.bgInverse,
                        c.bgInverseHi,
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.yellow.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.yellow.withValues(alpha: 0.18),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  child: widget.avatarUrl == null
                      ? _AvatarInitial(initial: widget.initial)
                      : Image.network(
                          widget.avatarUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _AvatarInitial(initial: widget.initial),
                        ),
                ),
              ),
            ),
          ),
          // Edit-photo affordance bottom-right — tiny floating button.
          Positioned(
            bottom: 12,
            right: 12,
            child: _EditPhotoButton(onTap: widget.onEditPhoto),
          ),
          // Goal-progress badge floating below the arc gap (bottom).
          Positioned(
            bottom: -6,
            left: 0,
            right: 0,
            child: Center(child: _GoalBadge(progress: widget.goalProgress)),
          ),
        ],
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Text(
      initial,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 64,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: -3.0,
        height: 1,
        color: c.yellow,
      ),
    );
  }
}

class _AvatarArcPainter extends CustomPainter {
  _AvatarArcPainter({
    required this.progress,
    required this.sweepProgress,
    required this.trackColor,
    required this.fillColor,
  });

  /// 0..100.
  final int progress;

  /// 0..1 — entry sweep progress.
  final double sweepProgress;

  final Color trackColor;
  final Color fillColor;

  /// Arc spans from ~7:30 around the top to ~4:30 — a ~310° wrap with
  /// a clean ~50° gap at the bottom for the goal badge.
  static const _startDeg = 115.0;
  static const _sweepDeg = 310.0;

  double _deg2rad(double d) => d * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 6;
    const stroke = 6.0;

    // Track.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _deg2rad(_startDeg),
      _deg2rad(_sweepDeg),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = trackColor,
    );

    // Fill.
    final fullFill = _sweepDeg * (progress.clamp(0, 100) / 100);
    final fillSweep = fullFill * sweepProgress;
    if (fillSweep > 0.01) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: _deg2rad(_startDeg),
          endAngle: _deg2rad(_startDeg + _sweepDeg),
          colors: [
            fillColor.withValues(alpha: 0.5),
            fillColor,
            fillColor,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: radius),
        );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _deg2rad(_startDeg),
        _deg2rad(fillSweep),
        false,
        paint,
      );

      // Bright tip dot at end of fill.
      final tipAngle = _deg2rad(_startDeg + fillSweep);
      final tip = Offset(
        center.dx + math.cos(tipAngle) * radius,
        center.dy + math.sin(tipAngle) * radius,
      );
      canvas.drawCircle(
        tip,
        stroke / 2 + 5,
        Paint()
          ..color = fillColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(tip, stroke / 2 + 1, Paint()..color = fillColor);
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarArcPainter old) =>
      old.progress != progress || old.sweepProgress != sweepProgress;
}

class _EditPhotoButton extends StatefulWidget {
  const _EditPhotoButton({this.onTap});
  final VoidCallback? onTap;

  @override
  State<_EditPhotoButton> createState() => _EditPhotoButtonState();
}

class _EditPhotoButtonState extends State<_EditPhotoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: c.yellow,
            shape: BoxShape.circle,
            border: Border.all(color: c.bgInverse, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.camera_alt_rounded,
            size: 13,
            color: c.yellowInk,
          ),
        ),
      ),
    );
  }
}

class _GoalBadge extends StatelessWidget {
  const _GoalBadge({required this.progress});
  final int progress;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
      decoration: BoxDecoration(
        color: c.bgInverse,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: c.yellow.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: c.yellow,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: c.yellow, blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$progress%',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.3,
              color: c.yellow,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'MỤC TIÊU',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: c.invInkSoft.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PHASE PILL — yellow-tinted chip with sparkle prefix.
// ═══════════════════════════════════════════════════════════════

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: c.yellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: c.yellow.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Sparkle(size: 11),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: c.yellow,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// INLINE STATS — compact uppercase row divided by yellow dots.
// ═══════════════════════════════════════════════════════════════

class _InlineStatsRow extends StatelessWidget {
  const _InlineStatsRow({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      widgets.add(
        Text(
          items[i],
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: c.invInk,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
      );
      if (i < items.length - 1) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: c.yellow,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: c.yellow, blurRadius: 4)],
              ),
            ),
          ),
        );
      }
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: widgets);
  }
}

// ═══════════════════════════════════════════════════════════════
// HERO PILL BUTTON — primary (yellow filled) or secondary (outline)
// ═══════════════════════════════════════════════════════════════

class _HeroPillButton extends StatefulWidget {
  const _HeroPillButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  State<_HeroPillButton> createState() => _HeroPillButtonState();
}

class _HeroPillButtonState extends State<_HeroPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final bg = widget.filled ? c.yellow : Colors.white.withValues(alpha: 0.06);
    final borderColor =
        widget.filled ? c.yellow : Colors.white.withValues(alpha: 0.20);
    final fg = widget.filled ? c.yellowInk : c.invInk;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: widget.filled
                ? [
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.36),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ATMOSPHERIC HELPERS
// ═══════════════════════════════════════════════════════════════

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });
  final Size size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class _GrainTexture extends StatelessWidget {
  const _GrainTexture({required this.opacity});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GrainPainter(opacity: opacity),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(331);
    final count = (size.width * size.height * 0.0009).round();
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = rng.nextDouble() * opacity;
      final tone = rng.nextDouble();
      paint.color =
          (tone > 0.5 ? Colors.white : Colors.black).withValues(alpha: a);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.opacity != opacity;
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SparklePainter(color: c.yellow)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
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
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}

class _LightStatusBar extends StatelessWidget {
  const _LightStatusBar();

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: SizedBox.shrink(),
    );
  }
}
