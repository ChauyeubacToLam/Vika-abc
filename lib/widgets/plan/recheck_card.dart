// RecheckCard — small cream card with a yellow left-border accent that flags
// the upcoming Recheck (re-assessment) day at the end of the current week.
// Stays subtle below the loud TodayCard.
//
// Mirrors `RecheckCard` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/plan_mock.dart';
import 'plan_typography.dart';
import '../../theme/app_colors.dart';
class RecheckCard extends StatelessWidget {
  const RecheckCard({super.key, required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: c.bgRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border(
            top: BorderSide(color: c.border),
            right: BorderSide(color: c.border),
            bottom: BorderSide(color: c.border),
            left: BorderSide(color: c.yellow, width: 4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PlanEyebrow(
                        'THỨ BẢY · ${day.date}',
                        size: 9,
                        letterSpacing: 1.4,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.yellowGhost,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'RECHECK',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: c.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  PlanH1(
                    day.title,
                    size: 17,
                    italic: true,
                    letterSpacing: -0.4,
                    height: 1.05,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.count} bài · Đo lại level và đề xuất tuần kế',
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
            const SizedBox(width: 14),
            // Decorative diamond, rotated 45°.
            Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c.bg,
                  border: Border.all(color: c.ink, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
