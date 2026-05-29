// IvoryBottomNav — frosted-glass pill capsule at the bottom of the main
// app shell. Five EQUAL tabs (Trang chủ, Lộ trình, Khám phá, Tiến bộ,
// Hồ sơ) — no floating FAB.
//
// Why 5 equal tabs (no FAB):
//   The prior center FAB ("circle button popping above the bar") read
//   as an orphan element. Premium app navs (Apple Music, Spotify,
//   Apple Fitness+) use equal-weight tabs in a pill — cleaner, more
//   iOS-native, and the visual rhythm is far more elegant than a giant
//   raised button breaking the bar's line.
//
// The center "Khám phá" tab opens the Library sheet via [onBrowse]
// (preserving the current overlay UX) instead of switching screens.
// Other 4 tabs map to the IndexedStack screens in MainShell via
// [onTap(int)].
//
// Active state: subtle yellow halo behind the icon + ink color + bold
// label. Inactive: faint stroke + faint label. Tap feedback: smooth
// 0.96 press scale + haptic selection click.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

class IvoryBottomNav extends StatelessWidget {
  const IvoryBottomNav({
    super.key,
    required this.currentIndex,
    required this.bottomInset,
    required this.onTap,
  });

  /// Screen index, 0..4: Home, Plan, Library, Progress, Profile.
  final int currentIndex;
  final double bottomInset;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Stack(
      children: [
        // Cream-fade gradient — content above the pill dissolves into
        // the cream background.
        IgnorePointer(
          child: Container(
            height: 80 + bottomInset,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  c.bg,
                  c.bg.withValues(alpha: 0.85),
                  c.bg.withValues(alpha: 0),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        ),
        // Pill capsule
        Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 4 + bottomInset),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: c.bgRaised.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.border),
                  boxShadow: [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.10),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: _NavIcon.home,
                        label: 'Trang chủ',
                        active: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: _NavIcon.plan,
                        label: 'Lộ trình',
                        active: currentIndex == 1,
                        onTap: () => onTap(1),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: _NavIcon.library,
                        label: 'Khám phá',
                        active: currentIndex == 2,
                        onTap: () => onTap(2),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: _NavIcon.progress,
                        label: 'Tiến bộ',
                        active: currentIndex == 3,
                        onTap: () => onTap(3),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: _NavIcon.profile,
                        label: 'Hồ sơ',
                        active: currentIndex == 4,
                        onTap: () => onTap(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _NavIcon { home, plan, library, progress, profile }

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final _NavIcon icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final labelColor = widget.active ? c.ink : c.inkFaint;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon area — when active, sits inside a subtle yellow
              // halo pill so the user feels the selection.
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.active ? c.yellowGhost : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CustomPaint(
                    painter: _NavIconPainter(
                      icon: widget.icon,
                      active: widget.active,
                      ink: c.ink,
                      inkFaint: c.inkFaint,
                      yellow: c.yellow,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9,
                  fontWeight: widget.active ? FontWeight.w800 : FontWeight.w700,
                  letterSpacing: 0.3,
                  color: labelColor,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconPainter extends CustomPainter {
  _NavIconPainter({
    required this.icon,
    required this.active,
    required this.ink,
    required this.inkFaint,
    required this.yellow,
  });

  final _NavIcon icon;
  final bool active;
  final Color ink;
  final Color inkFaint;
  final Color yellow;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 20;
    Offset p(double x, double y) => Offset(x * scale, y * scale);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = active ? ink : inkFaint;

    switch (icon) {
      case _NavIcon.home:
        // House outline
        final path = Path()
          ..moveTo(3 * scale, 9 * scale)
          ..lineTo(10 * scale, 3 * scale)
          ..lineTo(17 * scale, 9 * scale)
          ..lineTo(17 * scale, 17 * scale)
          ..lineTo(13 * scale, 17 * scale)
          ..lineTo(13 * scale, 12 * scale)
          ..lineTo(7 * scale, 12 * scale)
          ..lineTo(7 * scale, 17 * scale)
          ..lineTo(3 * scale, 17 * scale)
          ..close();
        canvas.drawPath(path, stroke);
        break;

      case _NavIcon.plan:
        // Calendar
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(3 * scale, 4 * scale, 17 * scale, 17 * scale),
          Radius.circular(2 * scale),
        );
        canvas.drawRRect(rect, stroke);
        canvas.drawLine(p(3, 8), p(17, 8), stroke);
        canvas.drawLine(p(7, 2), p(7, 6), stroke);
        canvas.drawLine(p(13, 2), p(13, 6), stroke);
        break;

      case _NavIcon.library:
        // Magnifying glass — universal "find / explore" glyph
        final cx = 9 * scale;
        final cy = 9 * scale;
        canvas.drawCircle(Offset(cx, cy), 6 * scale, stroke);
        canvas.drawLine(
          Offset(13.5 * scale, 13.5 * scale),
          Offset(17.5 * scale, 17.5 * scale),
          stroke,
        );
        break;

      case _NavIcon.progress:
        // Trending line + endpoint star
        final path = Path()
          ..moveTo(3 * scale, 16 * scale)
          ..lineTo(8 * scale, 11 * scale)
          ..lineTo(11 * scale, 14 * scale)
          ..lineTo(17 * scale, 7 * scale);
        canvas.drawPath(path, stroke);
        canvas.drawCircle(
          p(17, 7),
          2 * scale,
          Paint()..color = active ? yellow : Colors.transparent,
        );
        canvas.drawCircle(p(17, 7), 2 * scale, stroke);
        break;

      case _NavIcon.profile:
        // Head + shoulders
        final headRect = Rect.fromCircle(center: p(10, 7), radius: 3.5 * scale);
        canvas.drawArc(headRect, 0, 6.283, false, stroke);
        final shoulders = Path()
          ..moveTo(3 * scale, 17 * scale)
          ..arcToPoint(
            Offset(17 * scale, 17 * scale),
            radius: Radius.circular(7 * scale),
            clockwise: false,
          );
        canvas.drawPath(shoulders, stroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _NavIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.active != active;
}
