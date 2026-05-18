// IvoryBottomNav — frosted-glass capsule pill at the bottom of the main app
// shell. 4 tab items with a central yellow FAB ("Khám phá") that opens the
// Library/Browser sheet.
//
// Mirrors `BottomNav`, `NavItem`, and `BrowseFAB` in
// vika-main-app-ivory-v1.jsx — including the soft cream gradient that fades
// content above the capsule into transparency, so the nav feels like it's
// floating over the page.
//
// Active tab gets ink color + filled icon background; inactive tabs are
// muted ink with bare-stroke glyphs.

import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class IvoryBottomNav extends StatelessWidget {
  const IvoryBottomNav({
    super.key,
    required this.currentIndex,
    required this.bottomInset,
    required this.onTap,
    required this.onBrowse,
  });

  final int currentIndex; // 0..3 mapped to Home, Plan, Progress, Profile
  final double bottomInset;
  final ValueChanged<int> onTap;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Stack(
      children: [
        // Cream-fade gradient above the capsule so chrome dissolves into bg.
        IgnorePointer(
          child: Container(
            height: 130 + bottomInset,
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
        // The capsule itself.
        Padding(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 26 + bottomInset),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: c.bgRaised.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.border),
                  boxShadow: [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.10),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
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
                    _BrowseFAB(onTap: onBrowse),
                    Expanded(
                      child: _NavItem(
                        icon: _NavIcon.progress,
                        label: 'Tiến bộ',
                        active: currentIndex == 2,
                        onTap: () => onTap(2),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: _NavIcon.profile,
                        label: 'Hồ sơ',
                        active: currentIndex == 3,
                        onTap: () => onTap(3),
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

enum _NavIcon { home, plan, progress, profile }

class _NavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final color = active ? c.ink : c.inkFaint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(
                  painter: _NavIconPainter(
                    icon: icon,
                    active: active,
                    ink: c.ink,
                    inkFaint: c.inkFaint,
                    yellow: c.yellow,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: 0.3,
                    color: color,
                ),
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
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = active ? ink : inkFaint;

    final fillPaint = active
        ? (Paint()..color = yellow.withValues(alpha: 0.35))
        : null;

    switch (icon) {
      case _NavIcon.home:
        // House outline: 5 points (ridge, two eaves, walls, base).
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
        if (fillPaint != null) canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, stroke);
        break;

      case _NavIcon.plan:
        // Calendar.
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(3 * scale, 4 * scale, 17 * scale, 17 * scale),
          Radius.circular(2 * scale),
        );
        if (fillPaint != null) canvas.drawRRect(rect, fillPaint);
        canvas.drawRRect(rect, stroke);
        canvas.drawLine(p(3, 8), p(17, 8), stroke);
        canvas.drawLine(p(7, 2), p(7, 6), stroke);
        canvas.drawLine(p(13, 2), p(13, 6), stroke);
        break;

      case _NavIcon.progress:
        // Trending line + endpoint star.
        final path = Path()
          ..moveTo(3 * scale, 16 * scale)
          ..lineTo(8 * scale, 11 * scale)
          ..lineTo(11 * scale, 14 * scale)
          ..lineTo(17 * scale, 7 * scale);
        canvas.drawPath(path, stroke);
        canvas.drawCircle(
          p(17, 7),
          2 * scale,
          Paint()
            ..color = active ? yellow : Colors.transparent,
        );
        canvas.drawCircle(p(17, 7), 2 * scale, stroke);
        break;

      case _NavIcon.profile:
        // Head + shoulders.
        final headRect = Rect.fromCircle(center: p(10, 7), radius: 3.5 * scale);
        if (fillPaint != null) {
          canvas.drawArc(headRect, 0, 6.283, true, fillPaint);
        }
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

class _BrowseFAB extends StatelessWidget {
  const _BrowseFAB({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.yellow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.yellow.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(
                  painter: _BrowseGridPainter(ink: c.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrowseGridPainter extends CustomPainter {
  _BrowseGridPainter({required this.ink});

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 22;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..color = ink;
    void box(double x, double y) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * scale, y * scale, 7 * scale, 7 * scale),
          Radius.circular(1.5 * scale),
        ),
        stroke,
      );
    }
    box(3, 4);
    box(12, 4);
    box(3, 13);
    box(12, 13);
  }

  @override
  bool shouldRepaint(covariant _BrowseGridPainter oldDelegate) => false;
}
