// WeekFocusCard — the warm-dark hero card for the current week. Italic
// body-focus headline + small body diagram on the right + coach voice quote
// + compact footer (focus/sessions count).
//
// Mirrors `WeekFocusCard` in vika-main-app-ivory-v1.jsx — including the
// design notes that explicitly removed the "TRỌNG TÂM TUẦN NÀY" eyebrow
// and the giant decorative numeral.

import 'package:flutter/material.dart';

import '../../data/plan_mock.dart';
import '../../theme/vf_theme.dart';
import 'plan_painters.dart';
import 'plan_typography.dart';
import '../../theme/app_colors.dart';
class WeekFocusCard extends StatelessWidget {
  const WeekFocusCard({super.key, required this.week});

  final PlanWeek week;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        padding: const EdgeInsets.all(22),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.bgInverse,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            // Subtle yellow radial wash, top-right.
            Positioned(
              top: -50,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.yellow.withValues(alpha: 0.12),
                        c.yellow.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.65],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Body-focus headline + diagram side by side.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PlanH1(
                        week.bodyFocus,
                        size: 30,
                        dark: true,
                        letterSpacing: -1.5,
                        height: 0.95,
                      ),
                    ),
                    if (week.body == BodyRegion.hip)
                      const SizedBox(
                        width: 56,
                        height: 80,
                        child: CustomPaint(
                          painter: BodyDiagramPainter(highlightHip: true),
                        ),
                      ),
                  ],
                ),
                // Coach voice quote.
                if (week.coachLine != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: c.borderDark),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CoachMark(small: true),
                            const SizedBox(width: 8),
                            PlanEyebrow(
                              'HUẤN LUYỆN VIÊN GHI',
                              size: 9,
                              letterSpacing: 1.6,
                              dark: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        PlanP(
                          week.coachLine!,
                          dark: true,
                          size: 14,
                          italic: true,
                          letterSpacing: -0.2,
                          height: 1.45,
                        ),
                      ],
                    ),
                  ),
                ],
                // Compact footer: focus + this-week count.
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: c.borderDark),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 12,
                              letterSpacing: -0.1,
                            ),
                            children: [
                              TextSpan(
                                text: 'Bài thêm · ',
                                style: TextStyle(
                                  color: c.invInkFaint,
                                ),
                              ),
                              TextSpan(
                                text: week.focus,
                                style: TextStyle(
                                  color: c.invInk,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            fontFeatures: VikaIvoryMain.tabularFigures,
                          ),
                          children: [
                            TextSpan(
                              text: '${week.completed}',
                              style: TextStyle(
                                color: c.yellow,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${week.sessions} buổi',
                              style: TextStyle(
                                color: c.invInkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
