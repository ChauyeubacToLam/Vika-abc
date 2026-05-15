// SheetChrome — sheet drag handle, editorial header, and search bar at the
// top of the Library/Browser sheet.
//
// Mirrors `SheetHeader` and `SheetSearch` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: c.borderHi,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PlanEyebrow(
                      'THƯ VIỆN',
                      size: 10,
                      letterSpacing: 2,
                      tabular: true,
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    PlanEyebrow('100 BÀI', size: 10, letterSpacing: 2),
                  ],
                ),
                const SizedBox(height: 8),
                const PlanH1(
                  'Khám phá.',
                  size: 32,
                  letterSpacing: -1.4,
                  height: 0.95,
                ),
                const SizedBox(height: 8),
                const PlanP(
                  'Bài tập cho người Việt làm văn phòng. Tại nhà.',
                  soft: true,
                  size: 12,
                  height: 1.45,
                  letterSpacing: 0.1,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: c.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SheetSearch extends StatelessWidget {
  const SheetSearch({super.key});

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: c.bgRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 16,
              color: c.inkFaint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tìm "squat", "lưng", "yoga"...',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.inkFaint,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: c.border),
              ),
              child: Text(
                '⌘K',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: c.inkFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
