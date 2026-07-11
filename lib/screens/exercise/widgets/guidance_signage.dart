import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/vf_theme.dart';
import 'system_banner.dart';

// ═══════════════════════════════════════════════════════════════════════════
// GuidanceSignage — setup/safety guidance as airport signage.
//
// Guidance fires exactly when the user is far from the phone and often
// mid-motion ("step back", "turn sideways", "find better light"), so it works
// symbol-first: a large glyph center-screen that animates directionally where
// meaningful, a title of at most ~3 words at 30pt, and the existing smaller
// body copy retained below for the near-viewing case.
//
// The trigger vocabulary and the voice pipeline are untouched — this is
// presentation only. The scan/warn/info/pause mode accents keep their
// meaning. No BackdropFilter: the panel sits on a solid high-alpha warm-dark
// fill (workstream H).
//
// All animation is transform/opacity on a single repeating controller,
// breathing at ~0.6Hz — no flashing.
// ═══════════════════════════════════════════════════════════════════════════

/// How the glyph moves. Directional kinds animate *toward* the instruction
/// (step back = chevrons flowing away, rotate = the device glyph turning).
enum GuidanceGlyphKind {
  /// Move away from the phone — glyph recedes, chevrons flow downward/away.
  stepBack,

  /// Rotate the phone — glyph swings a quarter turn and back.
  rotate,

  /// Turn your body sideways — glyph squashes horizontally like a turn.
  turnSide,

  /// Face the camera — gentle beckoning pulse.
  faceCamera,

  /// Find better light — glow breathes.
  light,

  /// Scanning for a person — soft search pulse.
  search,

  /// Paused / static informational.
  still,
}

class GuidanceSignage extends StatefulWidget {
  const GuidanceSignage({
    super.key,
    required this.icon,
    required this.kind,
    required this.title,
    required this.body,
    required this.mode,
    this.compact = false,
    this.landscape = false,
  });

  final IconData icon;
  final GuidanceGlyphKind kind;
  final String title;
  final String body;
  final SystemBannerMode mode;

  /// Compact horizontal pill — reserved for cases where signage rides above
  /// another full-screen surface.
  final bool compact;

  /// Landscape sizing: the same centered glyph-above-title layout, scaled
  /// down so the stack fits the short viewport. (During guidance the center
  /// heroes are hidden, so the sign owns the middle of the screen.)
  final bool landscape;

  @override
  State<GuidanceSignage> createState() => _GuidanceSignageState();
}

class _GuidanceSignageState extends State<GuidanceSignage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Color get _accent => switch (widget.mode) {
        SystemBannerMode.warn => const Color(0xFFFFB4A8),
        SystemBannerMode.scan => const Color(0xCCFFFFFF),
        SystemBannerMode.pause => const Color(0xCCFFFFFF),
        SystemBannerMode.info => VikaIvory.yellow,
      };

  Color get _border => switch (widget.mode) {
        SystemBannerMode.warn => const Color(0x4DFFB4A8),
        SystemBannerMode.scan => const Color(0x22FFFFFF),
        SystemBannerMode.pause => const Color(0x22FFFFFF),
        SystemBannerMode.info => VikaIvory.yellowGlowWeak,
      };

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildCompact();
    // Same centered glyph-above-title stack in both orientations — just
    // scaled down in landscape so it fits the short viewport. Centering is
    // owned by the caller (a screen-filling Center); this only sizes itself.
    return widget.landscape
        ? _buildSign(glyphBox: 158, glyphSize: 108, titleSize: 54)
        : _buildSign(glyphBox: 200, glyphSize: 150, titleSize: 72);
  }

  /// The animated glyph inside its accent aura — shared by both full layouts.
  Widget _glyphHero(
      {required double boxWidth,
      required double boxHeight,
      required double glyphSize}) {
    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft accent aura — color carries state at any distance.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _accent.withValues(alpha: 0.24),
                  _accent.withValues(alpha: 0),
                ],
                stops: const [0, 0.85],
              ),
            ),
            child: SizedBox(width: boxWidth, height: boxHeight),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, _) =>
                  _buildGlyph(_motion.value, size: glyphSize),
            ),
          ),
        ],
      ),
    );
  }

  /// One centered stack: a big moving glyph above a short, upright title.
  /// No card, no box — the page dims the whole screen behind it (a gross,
  /// distance-readable mode change) and the sign floats dead-center. No body
  /// text: unreadable from 2 m and redundant with the voice channel.
  Widget _buildSign({
    required double glyphBox,
    required double glyphSize,
    required double titleSize,
  }) {
    return RepaintBoundary(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _glyphHero(
              boxWidth: glyphBox * 1.15,
              boxHeight: glyphBox,
              glyphSize: glyphSize,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 340,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VikaIvory.fontFamily,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: VikaIvory.invInk,
                    letterSpacing: -1.5,
                    height: 1.05,
                    shadows: [
                      Shadow(
                        color: VikaIvory.heroBg.withValues(alpha: 0.9),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact() {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: VikaIvory.heroBg.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 36,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) => _buildGlyph(_motion.value, size: 30),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: VikaIvory.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: VikaIvory.invInk,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The animated glyph. [t] is the 0–1 loop phase; every kind maps it to a
  /// transform/opacity, never a rebuild of new widgets.
  Widget _buildGlyph(double t, {double size = 76}) {
    // One smooth in-out sweep per loop.
    final wave = math.sin(t * 2 * math.pi); // -1 → 1
    final sweep = 0.5 - 0.5 * math.cos(t * 2 * math.pi); // 0 → 1 → 0

    final icon = Icon(widget.icon, size: size, color: _accent, shadows: [
      Shadow(
        color: VikaIvory.heroBg.withValues(alpha: 0.6),
        blurRadius: 8,
      ),
    ]);

    switch (widget.kind) {
      case GuidanceGlyphKind.stepBack:
        // The figure recedes while chevrons stream away beneath it.
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Transform.scale(scale: 1.0 - 0.10 * sweep, child: icon),
            Positioned.fill(
              child: CustomPaint(
                painter: _FlowChevronsPainter(
                  phase: t,
                  color: _accent,
                  pointDown: true,
                ),
              ),
            ),
          ],
        );
      case GuidanceGlyphKind.rotate:
        // Quarter-turn swing and back — the rotation is the instruction.
        return Transform.rotate(
          angle: sweep * math.pi / 2,
          child: icon,
        );
      case GuidanceGlyphKind.turnSide:
        // Horizontal squash reads as the body turning side-on.
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scaleByDouble(1.0 - 0.45 * sweep, 1.0, 1.0, 1.0),
          child: icon,
        );
      case GuidanceGlyphKind.faceCamera:
        return Transform.scale(scale: 1.0 + 0.06 * wave, child: icon);
      case GuidanceGlyphKind.light:
        return Opacity(opacity: 0.55 + 0.45 * sweep, child: icon);
      case GuidanceGlyphKind.search:
        return Transform.scale(
          scale: 1.0 + 0.05 * wave,
          child: Opacity(opacity: 0.62 + 0.38 * sweep, child: icon),
        );
      case GuidanceGlyphKind.still:
        return icon;
    }
  }
}

/// Three chevrons flowing in one direction — the "keep going that way"
/// signage primitive. Pure canvas strokes; the path is rebuilt from two lines
/// per chevron (no allocations beyond the Paint per frame).
class _FlowChevronsPainter extends CustomPainter {
  const _FlowChevronsPainter({
    required this.phase,
    required this.color,
    required this.pointDown,
  });

  final double phase;
  final Color color;
  final bool pointDown;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything scales off the canvas so the same painter serves both the
    // 140pt hero glyph and the compact pill variant.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(3.0, size.width * 0.022)
      ..strokeCap = StrokeCap.round;

    const chevrons = 3;
    final cx = size.width / 2;
    final laneTop = size.height * 0.62;
    final laneHeight = size.height * 0.38;
    final halfWidth = math.max(13.0, size.width * 0.11);
    final depth = halfWidth * 0.55;

    for (var i = 0; i < chevrons; i++) {
      // Each chevron rides the loop offset by a third, fading out as it
      // reaches the end of its travel.
      final local = (phase + i / chevrons) % 1.0;
      final y = laneTop + laneHeight * local;
      final fade = math.sin(local * math.pi);
      paint.color = color.withValues(alpha: 0.75 * fade);
      final tip = pointDown ? y + depth : y - depth;
      canvas.drawLine(Offset(cx - halfWidth, y), Offset(cx, tip), paint);
      canvas.drawLine(Offset(cx, tip), Offset(cx + halfWidth, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowChevronsPainter old) {
    return old.phase != phase || old.color != color;
  }
}
