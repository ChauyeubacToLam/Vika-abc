// HomeStageHero — Home's full-bleed dark canvas. Premium Ivory v3 polish.
//
// Carries today's action moment as one confident composition:
//   • Inverted WordmarkHeader
//   • Sparkle eyebrow ('HÔM NAY · BUỔI 03')
//   • Two-line italic display headline
//   • Compact stat row + breathing yellow "live" dot (single signature
//     heartbeat — no other motion on the page)
//   • Exercise list as a VERTICAL TIMELINE with connecting hairline +
//     dots (filled yellow when the camera-AI form coach is wired for that
//     slot; outlined otherwise). The dot's color carries the AI signal,
//     so the row body no longer needs an "AI" chip — single source of
//     visual truth per row.
//   • Yellow CTA pill with two-layer halo glow
//
// Atmospherics (painted inline, no V5 import):
//   • Warm yellow ambient glow, top-right shoulder
//   • Cooler amber glow, bottom-left
//   • Deterministic film grain (seed 73 — never time-based to avoid
//     shimmer on rebuild)
//   • 2 sparkle particles at low opacity, well away from text
//
// Bleeds to the screen's top edge via the parent screen's
// `MediaQuery.removePadding(removeTop: true)`. Curves into cream via a
// 36pt rounded bottom corner.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';
import '../ivory/atoms.dart';
import '../ivory/skeleton.dart';
import '../plan/plan_typography.dart';
import '../plan/wordmark_header.dart';

/// One exercise row in the session brief.
class HomeStageExercise {
  const HomeStageExercise({
    required this.name,
    required this.detail,
    this.hasAi = false,
    this.thumbnailAsset,
  });

  /// e.g. 'Squat'.
  final String name;

  /// e.g. '3 × 8 rep' — short volume label.
  final String detail;

  /// True when the camera-AI form coach is wired for this slot. Drives the
  /// gold AI pip on the thumbnail.
  final bool hasAi;

  /// Real exercise render (rounded-square thumbnail). Null → glyph fallback.
  final String? thumbnailAsset;
}

class HomeStageHero extends StatelessWidget {
  const HomeStageHero({
    super.key,
    required this.eyebrow,
    required this.titleLine1,
    required this.titleLine2,
    required this.duration,
    required this.totalCount,
    required this.aiCount,
    required this.exercises,
    required this.coachQuote,
    required this.coachAttribution,
    required this.ctaLabel,
    required this.onCta,
    required this.userInitial,
    this.avatarUrl,
    this.whyLine,
    this.ctaEmphasized = true,
    this.secondaryCtaLabel,
    this.onSecondaryCta,
    this.onAvatarTap,
    this.onNotificationsTap,
  });

  /// e.g. 'HÔM NAY · BUỔI 03'.
  final String eyebrow;
  final String titleLine1;
  final String titleLine2;
  final String duration; // '15 phút'
  final int totalCount; // 4
  final int aiCount; // 3
  final List<HomeStageExercise> exercises;

  /// Coach voice line — sits as a hairline-separated final moment inside
  /// the session brief card. Replaces the standalone coach card below.
  final String coachQuote;

  /// Short attribution shown after the coach quote, e.g. 'Vika'.
  final String coachAttribution;

  final String ctaLabel;
  final VoidCallback? onCta;
  final String? whyLine;
  final bool ctaEmphasized;
  final String? secondaryCtaLabel;
  final VoidCallback? onSecondaryCta;

  final String userInitial;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final hasPrimaryCta = onCta != null && ctaLabel.isNotEmpty;
    final hasSecondaryCta =
        onSecondaryCta != null && (secondaryCtaLabel?.isNotEmpty ?? false);

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
            // ─── Atmosphere ──────────────────────────────────────
            Positioned(
              top: -130,
              right: -110,
              child: IgnorePointer(
                child: _AmbientGlow(
                  size: const Size(420, 420),
                  color: c.yellow,
                  opacity: 0.24,
                ),
              ),
            ),
            Positioned(
              bottom: -180,
              left: -140,
              child: IgnorePointer(
                child: _AmbientGlow(
                  size: const Size(440, 380),
                  color: const Color(0xFFCD7C45),
                  opacity: 0.18,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: const _GrainTexture(opacity: 0.05),
              ),
            ),
            const Positioned(
              top: 190,
              right: 56,
              child: IgnorePointer(
                child: Opacity(opacity: 0.42, child: _Sparkle(size: 12)),
              ),
            ),
            const Positioned(
              top: 360,
              left: 38,
              child: IgnorePointer(
                child: Opacity(opacity: 0.28, child: _Sparkle(size: 9)),
              ),
            ),

            // ─── Content ─────────────────────────────────────────
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
                    trailingIcon: Icons.notifications_none_rounded,
                    trailingTooltip: 'Thông báo',
                    onTrailingTap: onNotificationsTap,
                    onAvatarTap: onAvatarTap,
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _EyebrowSparkle(label: eyebrow),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _Headline(line1: titleLine1, line2: titleLine2),
                  ),
                  if (whyLine != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        whyLine!,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: c.invInkSoft,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _StatRow(
                      duration: duration,
                      total: totalCount,
                      ai: aiCount,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SessionBrief(
                      items: exercises,
                      coachQuote: coachQuote,
                      coachAttribution: coachAttribution,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (hasPrimaryCta || hasSecondaryCta) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          if (hasPrimaryCta)
                            _StartButton(
                              label: ctaLabel,
                              onTap: onCta!,
                              emphasized: ctaEmphasized,
                            ),
                          if (hasPrimaryCta && hasSecondaryCta)
                            const SizedBox(height: 10),
                          if (hasSecondaryCta)
                            _SecondaryButton(
                              label: secondaryCtaLabel!,
                              onTap: onSecondaryCta!,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                  ] else
                    const SizedBox(height: 8),
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
// LOADING SKELETON — same dark stage, shimmering placeholders
// ═══════════════════════════════════════════════════════════════
//
// Shown while today's session resolves. Mirrors the real hero's layout
// (eyebrow → headline → stat row → session brief → CTA) so the swap to
// real content lands without a layout jump. The brand wordmark stays real
// — it's identity, not data — and sits outside the Shimmer.

class HomeStageHeroSkeleton extends StatelessWidget {
  const HomeStageHeroSkeleton({
    super.key,
    required this.userInitial,
    this.avatarUrl,
    this.onAvatarTap,
    this.onNotificationsTap,
  });

  final String userInitial;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
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
            Positioned(
              top: -130,
              right: -110,
              child: IgnorePointer(
                child: _AmbientGlow(
                  size: const Size(420, 420),
                  color: c.yellow,
                  opacity: 0.16,
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(child: _GrainTexture(opacity: 0.05)),
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
                    trailingIcon: Icons.notifications_none_rounded,
                    trailingTooltip: 'Thông báo',
                    onTrailingTap: onNotificationsTap,
                    onAvatarTap: onAvatarTap,
                  ),
                  const SizedBox(height: 22),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Shimmer(
                      inverted: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Eyebrow
                          SkeletonBox(width: 150, height: 12, inverted: true),
                          SizedBox(height: 20),
                          // Headline — two lines
                          SkeletonBox(
                              width: 240,
                              height: 36,
                              radius: 9,
                              inverted: true),
                          SizedBox(height: 11),
                          SkeletonBox(
                              width: 168,
                              height: 36,
                              radius: 9,
                              inverted: true),
                          SizedBox(height: 20),
                          // Stat row
                          Row(
                            children: [
                              SkeletonBox(width: 70, height: 12, inverted: true),
                              SizedBox(width: 14),
                              SkeletonBox(width: 52, height: 12, inverted: true),
                              SizedBox(width: 14),
                              SkeletonBox(width: 62, height: 12, inverted: true),
                            ],
                          ),
                          SizedBox(height: 18),
                          // Session brief card
                          _BriefSkeleton(),
                          SizedBox(height: 18),
                          // CTA pill
                          SkeletonBox(
                            height: 54,
                            radius: 999,
                            inverted: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder mirroring the session-brief card: a few timeline rows + a
/// hairline + a coach-voice line.
class _BriefSkeleton extends StatelessWidget {
  const _BriefSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const SkeletonBox(
                      width: 52, height: 52, radius: 13, inverted: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SkeletonBox(
                      width: 120.0 + (i.isEven ? 40 : 0),
                      height: 13,
                      inverted: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const SkeletonBox(width: 46, height: 26, radius: 10, inverted: true),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonCircle(size: 16, inverted: true),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 12, inverted: true),
                    SizedBox(height: 8),
                    SkeletonBox(width: 160, height: 12, inverted: true),
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
// EYEBROW + HEADLINE
// ═══════════════════════════════════════════════════════════════

class _EyebrowSparkle extends StatelessWidget {
  const _EyebrowSparkle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Sparkle(size: 13),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.9,
            color: c.yellow,
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.line1, required this.line2});
  final String line1;
  final String line2;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line1,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 44,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -2.4,
            height: 0.94,
            color: c.invInk,
          ),
        ),
        Text(
          line2,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 44,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -2.4,
            height: 0.94,
            color: c.invInk,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STAT ROW
// ═══════════════════════════════════════════════════════════════

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.duration,
    required this.total,
    required this.ai,
  });

  final String duration;
  final int total;
  final int ai;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        _Stat(icon: Icons.access_time_rounded, label: duration),
        const SizedBox(width: 14),
        Container(width: 1, height: 14, color: c.borderDark),
        const SizedBox(width: 14),
        _Stat(icon: Icons.check_circle_outline_rounded, label: '$total bài'),
        if (ai > 0) ...[
          const SizedBox(width: 14),
          Container(width: 1, height: 14, color: c.borderDark),
          const SizedBox(width: 14),
          const _LiveDot(),
          const SizedBox(width: 8),
          Text(
            '$ai có AI',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: c.invInkSoft,
              fontFeatures: VikaIvoryMain.tabularFigures,
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.yellow),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: c.invInk,
            fontFeatures: VikaIvoryMain.tabularFigures,
          ),
        ),
      ],
    );
  }
}

/// The single page-wide motion signature. Subtle 2s breath on a 6pt yellow
/// dot — no other element animates. Premium fitness apps lean on a single
/// "heartbeat" element; more than one feels nervous.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: c.yellow,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.35 + t * 0.45),
                blurRadius: 8 + t * 8,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SESSION BRIEF — exercise timeline + embedded coach voice
// ═══════════════════════════════════════════════════════════════
//
// One self-contained card carrying everything the user needs to know
// about today's workout before pressing the CTA:
//   1. Header eyebrow
//   2. Vertical timeline of exercises (uniform gold dots — the AI signal
//      lives as a yellow inline accent in the detail line, not in the
//      dot color which was reading as inconsistency)
//   3. Hairline divider
//   4. Coach voice quote with a small CoachMark glyph
//
// Putting coach IN here means the page no longer has a separate "coach
// card" stacked below — the action surface is one cohesive moment.

class _SessionBrief extends StatelessWidget {
  const _SessionBrief({
    required this.items,
    required this.coachQuote,
    required this.coachAttribution,
  });

  final List<HomeStageExercise> items;
  final String coachQuote;
  final String coachAttribution;

  @override
  Widget build(BuildContext context) {
    // A contained glass panel — the dark-register sibling of the Plan tab's
    // session panel (same structure: a bordered container holding distinct
    // exercise chips + the coach voice). Keeps the two tabs reading as one app.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold-dot header — mirrors the Plan session panel's opening label
          // so both tabs' session blocks read as one family.
          const _BriefHeader(label: 'BÀI TẬP'),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _BriefChip(item: items[i]),
          ],
          const SizedBox(height: 14),
          // Hairline separates the workout list from the coach voice.
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),
          _CoachVoice(quote: coachQuote, attribution: coachAttribution),
        ],
      ),
    );
  }
}

/// Gold-dot + tracked label that opens the session panel — the dark-register
/// twin of the Plan panel's `_EntryHeader`, so both tabs' blocks open alike.
class _BriefHeader extends StatelessWidget {
  const _BriefHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: c.yellow,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: c.yellow.withValues(alpha: 0.5), blurRadius: 7),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: c.yellow,
          ),
        ),
      ],
    );
  }
}

/// One exercise as a distinct dark chip — thumbnail + name + a glass volume
/// pill, mirroring the Plan tab's powder exercise chips in the dark register.
class _BriefChip extends StatelessWidget {
  const _BriefChip({required this.item});

  final HomeStageExercise item;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SessionExerciseThumb(
            asset: item.thumbnailAsset,
            size: 52,
            radius: 13,
            inverted: true,
            showAi: item.hasAi,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: c.invInk,
              ),
            ),
          ),
          if (item.detail.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.detail,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  color: c.invInkSoft,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COACH VOICE (embedded inside session brief)
// ═══════════════════════════════════════════════════════════════

class _CoachVoice extends StatelessWidget {
  const _CoachVoice({required this.quote, required this.attribution});

  final String quote;
  final String attribution;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    // Same CoachMark + italic line the Plan's ProgramCoachNote uses, so the
    // coaching voice reads identically across tabs (here with attribution).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: CoachMark(small: true),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: frauncesItalic(
                size: 13.5,
                weight: FontWeight.w600,
                letterSpacing: -0.15,
                height: 1.5,
                color: c.invInk,
              ),
              children: [
                TextSpan(text: '“$quote”'),
                TextSpan(
                  text: '   — $attribution',
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    fontSize: 10.5,
                    color: c.invInkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CTA
// ═══════════════════════════════════════════════════════════════

class _StartButton extends StatefulWidget {
  const _StartButton({
    required this.label,
    required this.onTap,
    required this.emphasized,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final bg =
        widget.emphasized ? c.yellow : Colors.white.withValues(alpha: 0.12);
    final fg = widget.emphasized ? c.yellowInk : c.invInk;
    final knobBg =
        widget.emphasized ? c.ink : Colors.white.withValues(alpha: 0.12);
    final knobFg = widget.emphasized ? c.yellow : c.invInkSoft;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 0, 6, 0),
          height: 54,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: widget.emphasized
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: widget.emphasized
                ? [
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.36),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: c.yellow.withValues(alpha: 0.18),
                      blurRadius: 60,
                      offset: const Offset(0, 26),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: fg,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: knobBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: knobFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 48,
          padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: c.yellow.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.self_improvement_rounded,
                  size: 16,
                  color: c.yellow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: c.invInk,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 18, color: c.invInkSoft),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ATMOSPHERIC HELPERS (inlined — no v5_primitives import)
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
    final rng = math.Random(73);
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
