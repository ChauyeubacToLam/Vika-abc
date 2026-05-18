// Typography primitives for the Premium Ivory main app.
//
// Single-family system: **Be Vietnam Pro** for everything (display + body
// + labels). Designed in Hanoi by Lâm Bảo specifically for Vietnamese
// diacritic stacks. Bundled in pubspec.yaml at weights 400/500/700/800
// with italics — no runtime fetch.
//
// The two helper functions below — `frauncesItalic` and `beVietnamPro`
// — are historical names retained for backwards compatibility with
// ~120 call-sites in the widgets. They now both produce
// `TextStyle(fontFamily: 'BeVietnamPro', ...)`. The italic helper hard-
// codes `FontStyle.italic`; the upright helper accepts a style param.
//
// Naming: kept (Plan*) for backwards compatibility with existing usages.

import 'package:flutter/material.dart';

import '../../theme/vf_theme.dart';

// ─── Font helpers ───────────────────────────────────────────────────────────

/// Italic Be Vietnam Pro for display moments (italic stat values,
/// editorial italic body, coach-voice quotes). Hard-codes
/// `FontStyle.italic` — caller doesn't need to think about it.
TextStyle frauncesItalic({
  required double size,
  FontWeight weight = FontWeight.w700,
  Color color = VikaIvoryMain.ink,
  double? letterSpacing,
  double? height,
  List<FontFeature>? fontFeatures,
}) {
  return TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: size,
    fontWeight: weight,
    fontStyle: FontStyle.italic,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
    fontFeatures: fontFeatures,
  );
}

/// Upright Be Vietnam Pro for body, eyebrows, numerals. Accepts an
/// optional `style:` for the rare cases where italic body is desired
/// (most italic body should route through `frauncesItalic` instead).
TextStyle beVietnamPro({
  required double size,
  FontWeight weight = FontWeight.w500,
  FontStyle style = FontStyle.normal,
  Color color = VikaIvoryMain.ink,
  double? letterSpacing,
  double? height,
  List<FontFeature>? fontFeatures,
}) {
  return TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: size,
    fontWeight: weight,
    fontStyle: style,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
    fontFeatures: fontFeatures,
  );
}

// ─── Eyebrow ────────────────────────────────────────────────────────────────
// Tracked uppercase label. Carries informational content (date label,
// section name, set number) so accessibility-wise it's TEXT, not
// decoration. Default color routes through `inkSoft` (AAA on cream)
// rather than `inkFaint` (which fails AA at this size). The dark variant
// uses `invInkSoft` (AA on warm-dark) for the same reason. See
// docs/contrast-report.md for ratios.
class PlanEyebrow extends StatelessWidget {
  const PlanEyebrow(
    this.text, {
    super.key,
    this.dark = false,
    this.color,
    this.size = 10,
    this.letterSpacing = 2,
    this.tabular = false,
  });

  final String text;
  final bool dark;
  final Color? color;
  final double size;
  final double letterSpacing;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: beVietnamPro(
        size: size,
        weight: FontWeight.w800,
        letterSpacing: letterSpacing,
        height: 1.2,
        color: color ??
            (dark ? VikaIvoryMain.invInkSoft : VikaIvoryMain.inkSoft),
        fontFeatures: tabular ? VikaIvoryMain.tabularFigures : null,
      ),
    );
  }
}

// ─── Italic display headline ────────────────────────────────────────────────
// The signature design device. Italic Fraunces 700 at 18–80pt with
// negative letterspacing — *Tuần 03*, *Khoẻ hơn rõ rệt.*, *Đẩy mạnh.*
//
// When `italic: false` is passed (rare), swaps to Be Vietnam Pro upright
// at the same weight. Fraunces upright is intentionally NOT used.
class PlanH1 extends StatelessWidget {
  const PlanH1(
    this.text, {
    super.key,
    this.size = 36,
    this.dark = false,
    this.color,
    this.italic = true,
    this.letterSpacing = -1.6,
    this.height = 0.95,
    this.weight = FontWeight.w700,
  });

  final String text;
  final double size;
  final bool dark;
  final Color? color;
  final bool italic;
  final double letterSpacing;
  final double height;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? (dark ? VikaIvoryMain.invInk : VikaIvoryMain.ink);
    final style = italic
        ? frauncesItalic(
            size: size,
            weight: weight,
            letterSpacing: letterSpacing,
            height: height,
            color: resolvedColor,
          )
        : beVietnamPro(
            size: size,
            weight: weight,
            letterSpacing: letterSpacing,
            height: height,
            color: resolvedColor,
          );
    return Text(text, style: style);
  }
}

// ─── Body text ──────────────────────────────────────────────────────────────
// 13-14pt for paragraphs, captions, supporting lines.
//
// Italic body text (e.g. coach quotes) routes to Fraunces. Upright body
// stays Be Vietnam Pro for readability.
class PlanP extends StatelessWidget {
  const PlanP(
    this.text, {
    super.key,
    this.dark = false,
    this.soft = false,
    this.size = 13,
    this.weight = FontWeight.w500,
    this.italic = false,
    this.height = 1.45,
    this.letterSpacing,
    this.color,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final bool dark;
  final bool soft;
  final double size;
  final FontWeight weight;
  final bool italic;
  final double height;
  final double? letterSpacing;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        (dark
            ? (soft ? VikaIvoryMain.invInkSoft : VikaIvoryMain.invInk)
            : (soft ? VikaIvoryMain.inkSoft : VikaIvoryMain.ink));
    // Fraunces italic at body sizes wants slightly heavier than the sans
    // equivalent to match optical weight — bump 500 → 600 for italic body
    // unless caller overrode.
    final effectiveWeight =
        italic && weight == FontWeight.w500 ? FontWeight.w600 : weight;

    final style = italic
        ? frauncesItalic(
            size: size,
            weight: effectiveWeight,
            letterSpacing: letterSpacing,
            height: height,
            color: resolved,
          )
        : beVietnamPro(
            size: size,
            weight: effectiveWeight,
            letterSpacing: letterSpacing,
            height: height,
            color: resolved,
          );
    return Text(text, maxLines: maxLines, overflow: overflow, style: style);
  }
}

// ─── CoachMark glyph ────────────────────────────────────────────────────────
// Yellow disc with a tiny ink stick figure. Sits next to the
// "HUẤN LUYỆN VIÊN GHI" eyebrow, marking coach-voice quotes.
class CoachMark extends StatelessWidget {
  const CoachMark({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 14.0 : 18.0;
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _CoachMarkInline()),
    );
  }
}

class _CoachMarkInline extends CustomPainter {
  const _CoachMarkInline();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 18;
    Offset p(double x, double y) => Offset(x * scale, y * scale);

    canvas.drawCircle(
      p(9, 9),
      8.5 * scale,
      Paint()..color = VikaIvoryMain.yellow,
    );
    canvas.drawCircle(
      p(9, 9),
      8.5 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * scale
        ..color = VikaIvoryMain.ink,
    );

    final ink = Paint()
      ..color = VikaIvoryMain.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(p(9, 5.5), 1.1 * scale,
        Paint()..color = VikaIvoryMain.ink);
    canvas.drawLine(p(9, 6.6), p(9, 10), ink);
    canvas.drawLine(p(6.5, 8), p(11.5, 8), ink);
    canvas.drawLine(p(9, 10), p(7.5, 13), ink);
    canvas.drawLine(p(9, 10), p(10.5, 13), ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
