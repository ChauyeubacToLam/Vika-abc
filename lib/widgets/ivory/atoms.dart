// Shared atoms for the Premium Ivory main-app screens. Each is small,
// self-contained, and used by multiple tabs.
//
// Mirrors atomic widgets in vika-main-app-ivory-v1.jsx:
//   • PoseGlyph  — small line-art glyph per exercise pose (Squat, Wall
//                  Push-up, Plank, Lunge). Used inside Library cards and
//                  exercise rows.
//   • AIDot      — yellow filled dot with thin ring. Indicates "camera AI"
//                  on an exercise — replaces the louder "AI FORM" tag.
//   • PillCTA    — yellow rounded pill CTA used on Home + Library.
//
// These widgets stay typographically consistent with VikaIvoryMain — same
// font, same letterspacing rules.

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// ─── PoseGlyph ──────────────────────────────────────────────────────────────
enum PoseGlyphType { squat, wallPushUp, plank, lunge }

class PoseGlyph extends StatelessWidget {
  const PoseGlyph({
    super.key,
    required this.type,
    this.size = 28,
    this.dark = true,
  });

  final PoseGlyphType type;
  final double size;
  final bool dark; // dark surface (warm-dark) vs light (cream)

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PoseGlyphPainter(
          type: type,
          dark: dark,
          stroke: dark ? c.invInkFaint : c.inkSoft,
          yellow: c.yellow,
        ),
      ),
    );
  }
}

class _PoseGlyphPainter extends CustomPainter {
  _PoseGlyphPainter({
    required this.type,
    required this.dark,
    required this.stroke,
    required this.yellow,
  });

  final PoseGlyphType type;
  final bool dark;
  final Color stroke;
  final Color yellow;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 28;
    Offset p(double x, double y) => Offset(x * scale, y * scale);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..strokeCap = StrokeCap.round
      ..color = stroke;

    final accent = Paint()
      ..color = yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * scale;

    final fill = Paint()..color = strokePaint.color;

    switch (type) {
      case PoseGlyphType.squat:
        // Head + torso bent forward + arms forward + legs squat.
        canvas.drawCircle(p(14, 6), 2 * scale, fill);
        canvas.drawLine(p(14, 8), p(14, 14), strokePaint);
        canvas.drawLine(p(14, 14), p(11, 19), strokePaint);
        canvas.drawLine(p(14, 14), p(17, 19), strokePaint);
        canvas.drawLine(p(11, 19), p(10, 23), strokePaint);
        canvas.drawLine(p(17, 19), p(18, 23), strokePaint);
        canvas.drawCircle(p(14, 6), 2.5 * scale,
            accent..color = yellow.withValues(alpha: 0.5));
        break;

      case PoseGlyphType.wallPushUp:
        // Vertical wall on right + body leaning + arms extended to wall.
        final wallPaint = Paint()
          ..color = yellow.withValues(alpha: 0.5)
          ..strokeWidth = 0.8 * scale
          ..style = PaintingStyle.stroke;
        canvas.drawLine(p(22, 3), p(22, 25), wallPaint);
        canvas.drawCircle(p(9, 9), 2 * scale, fill);
        canvas.drawLine(p(9, 11), p(11, 18), strokePaint);
        canvas.drawLine(p(11, 18), p(15, 17), strokePaint);
        canvas.drawLine(p(11, 18), p(15, 22), strokePaint);
        canvas.drawLine(p(15, 17), p(19, 14), strokePaint);
        canvas.drawLine(p(15, 21), p(19, 18), strokePaint);
        break;

      case PoseGlyphType.plank:
        // Ground line + body horizontal.
        final groundPaint = Paint()
          ..color = yellow.withValues(alpha: 0.5)
          ..strokeWidth = 0.8 * scale;
        canvas.drawLine(p(2, 22), p(26, 22), groundPaint);
        canvas.drawCircle(p(6, 14), 2 * scale, fill);
        canvas.drawLine(p(8, 14), p(20, 14), strokePaint);
        canvas.drawLine(p(20, 14), p(20, 20), strokePaint);
        canvas.drawLine(p(20, 14), p(23, 20), strokePaint);
        canvas.drawLine(p(8, 14), p(8, 20), strokePaint);
        canvas.drawLine(p(11, 14), p(10, 20), strokePaint);
        break;

      case PoseGlyphType.lunge:
        // Head + torso vertical + front leg bent + back leg extended.
        canvas.drawCircle(p(14, 5), 2 * scale, fill);
        canvas.drawLine(p(14, 7), p(14, 15), strokePaint);
        canvas.drawLine(p(14, 15), p(10, 19), strokePaint);
        canvas.drawLine(p(10, 19), p(8, 23), strokePaint);
        canvas.drawLine(p(14, 15), p(19, 18), strokePaint);
        canvas.drawLine(p(19, 18), p(22, 23), strokePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PoseGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.dark != dark;
}

// ─── AIDot ──────────────────────────────────────────────────────────────────
// Yellow filled dot with thin outer ring at 50% opacity. Indicates an
// exercise has AI camera form analysis. Counts as one of the 4 yellow uses.
class AIDot extends StatelessWidget {
  const AIDot({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final size = small ? 10.0 : 12.0;
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 6,
            height: size + 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: c.yellow.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: c.yellow,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PillCTA ────────────────────────────────────────────────────────────────
// Yellow pill CTA with right-side circle arrow. Used on Home + inside the
// Library AI camera spotlight.
class PillCTA extends StatelessWidget {
  const PillCTA({
    super.key,
    required this.label,
    required this.onTap,
    this.dark = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool
      dark; // dark = ink pill (used on warm-dark surfaces); light = yellow
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final bg = dark ? c.invInk : c.yellow;
    final fg = dark ? c.ink : c.yellowInk;
    final knobBg = dark ? c.yellow : c.ink;
    final knobFg = dark ? c.yellowInk : c.yellow;

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: fg,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: knobBg, shape: BoxShape.circle),
                alignment: Alignment.center,
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

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
