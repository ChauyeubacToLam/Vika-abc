// BrowseShortcut — wide cream card at the bottom of the Home scroll
// inviting the user to open the Library. Yellow icon tile + italic
// "Khám phá thêm" + meta + chevron.
//
// Mirrors the "Khám phá thêm" CTA card at the bottom of the Home tab in
// vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class BrowseShortcut extends StatelessWidget {
  const BrowseShortcut({
    super.key,
    required this.onTap,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 0),
  });

  final VoidCallback onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: padding,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.yellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(painter: _MiniGridPainter(ink: c.ink)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Khám phá thêm',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.4,
                          color: c.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '100 bài tập · 20 có camera AI',
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: c.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniGridPainter extends CustomPainter {
  const _MiniGridPainter({required this.ink});

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 18;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..color = ink;
    void box(double x, double y) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * scale, y * scale, 6 * scale, 6 * scale),
          Radius.circular(1.2 * scale),
        ),
        stroke,
      );
    }

    box(2, 2);
    box(10, 2);
    box(2, 10);
    box(10, 10);
  }

  @override
  bool shouldRepaint(covariant _MiniGridPainter oldDelegate) => false;
}
