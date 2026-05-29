// Shared atoms for the completion-anchored Plan redesign ("Progress Ledger
// on a Spine"). These mirror the atmosphere + coach-voice recipe used by the
// existing Stage heroes (DashboardHomeScreen / PlanStageHero) so the new Plan
// surfaces feel like the same app — warm-dark gradient, yellow ambient glow,
// deterministic film grain (seed 91, never time-based), sparkles, and the
// glass coach-voice card.
//
// Yellow stays reserved (stat / dot / underline / CTA). Phase accents are NOT
// used here — they appear only as the 2px margin rule in ProgramBlockSequence.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/program_mock.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/responsive.dart';
import '../../../theme/vf_theme.dart';
import '../plan_typography.dart';

/// Light status-bar icons over the warm-dark hero (transparent bar).
class ProgramLightStatusBar extends StatelessWidget {
  const ProgramLightStatusBar({super.key});

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

// ═══════════════════════════════════════════════════════════════
// ATMOSPHERE — glow, grain, sparkle (copied to match the shipped hero)
// ═══════════════════════════════════════════════════════════════

/// Soft radial wash — the "publication masthead light". Anchor off-canvas.
class ProgramAmbientGlow extends StatelessWidget {
  const ProgramAmbientGlow({
    super.key,
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

/// Deterministic film grain. Seeded (91) so it never shimmers between frames.
class ProgramGrain extends StatelessWidget {
  const ProgramGrain({super.key, this.opacity = 0.05});

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
    final rng = math.Random(91);
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

/// A small four-point yellow sparkle.
class ProgramSparkle extends StatelessWidget {
  const ProgramSparkle({super.key, required this.size, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SparklePainter(color: color ?? c.yellow)),
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

// ═══════════════════════════════════════════════════════════════
// COACH NOTE — the "huấn luyện viên ghi" voice as a lean inline line
// ═══════════════════════════════════════════════════════════════

/// CoachMark + an italic coach line. No card chrome — it sits inline so the
/// coaching voice is present without adding a heavy block of text. Works on
/// warm-dark (`dark: true`) and cream surfaces.
class ProgramCoachNote extends StatelessWidget {
  const ProgramCoachNote({
    super.key,
    required this.text,
    this.dark = false,
    this.soft = false,
    this.size = 13,
    this.maxLines,
  });

  final String text;
  final bool dark;

  /// Use the lower-emphasis ink (e.g. done-session recaps, upcoming previews).
  final bool soft;
  final double size;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final color = dark
        ? (soft ? c.invInkSoft : c.invInk)
        : (soft ? c.inkFaint : c.inkSoft);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: CoachMark(small: true),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: frauncesItalic(
              size: size,
              weight: FontWeight.w600,
              letterSpacing: -0.1,
              height: 1.45,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CTA PILLS — the one halo launch + the disabled glass variants
// ═══════════════════════════════════════════════════════════════

/// The single launch button: yellow pill, ink knob, yellow arrow, two-layer
/// glow (one of the two sanctioned shadow exceptions). For warm-dark surfaces.
class ProgramHaloCta extends StatefulWidget {
  const ProgramHaloCta({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<ProgramHaloCta> createState() => _ProgramHaloCtaState();
}

class _ProgramHaloCtaState extends State<ProgramHaloCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
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
          height: 56,
          decoration: BoxDecoration(
            color: c.yellow,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.38),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: c.yellow.withValues(alpha: 0.18),
                blurRadius: 68,
                offset: const Offset(0, 30),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: beVietnamPro(
                    size: r.sp(15.5),
                    weight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: c.yellowInk,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 19, color: c.yellow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Disabled glass pill (done / locked states) for warm-dark surfaces — no
/// glow, hairline border, outlined knob. Never tappable.
class ProgramGlassPill extends StatelessWidget {
  const ProgramGlassPill({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 0, 6, 0),
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: beVietnamPro(
                size: r.sp(15),
                weight: FontWeight.w800,
                letterSpacing: -0.3,
                color: c.invInkSoft,
              ),
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22), width: 1.2),
            ),
            child: Icon(icon, size: 19, color: c.invInkSoft),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DIFFICULTY PILL — Nhẹ / Vừa sức / Nặng (warmth-coded, never red)
// ═══════════════════════════════════════════════════════════════

/// Glanceable chip for the difficulty the user logged. Difficulty is
/// information, never judgment — `Nặng` uses warm `attention`, never red.
class DifficultyPill extends StatelessWidget {
  const DifficultyPill(
      {super.key, required this.difficulty, this.compact = false});

  final SessionDifficulty difficulty;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final (Color fill, Color text) = switch (difficulty) {
      SessionDifficulty.light => (c.powder, c.inkSoft),
      SessionDifficulty.moderate => (c.yellowGhost, c.ink),
      SessionDifficulty.hard => (
          c.attention.withValues(alpha: 0.14),
          c.attention
        ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        difficulty.label,
        style: beVietnamPro(
          size: compact ? 10 : 11,
          weight: FontWeight.w700,
          letterSpacing: -0.1,
          color: text,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION MARK — yellow bar + tracked label + hairline + index numeral
// ═══════════════════════════════════════════════════════════════

/// The magazine "§ chapter" rule: a 4×22 yellow bar (the reserved "underline"
/// use), a tracked uppercase label, a hairline, and an optional right-aligned
/// tabular index ("02 / 03").
class ProgramSectionMark extends StatelessWidget {
  const ProgramSectionMark({
    super.key,
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 0),
  });

  final String label;

  /// Right-aligned index numeral, e.g. "02 / 03" or "7 KHỐI". Null hides it.
  final String? trailing;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: c.yellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: beVietnamPro(
                size: 12,
                weight: FontWeight.w800,
                letterSpacing: 1.6,
                color: c.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Container(height: 1, color: c.border)),
          if (trailing != null) ...[
            const SizedBox(width: 14),
            Text(
              trailing!,
              style: beVietnamPro(
                size: 11,
                weight: FontWeight.w800,
                letterSpacing: 1.0,
                color: c.inkFaint,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
