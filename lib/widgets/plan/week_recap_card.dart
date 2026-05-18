// WeekRecapCard — the dominant moment of a done-week page. Warm-dark card
// with a yellow radial wash (top-left), 3-stat trio (sessions / form % /
// peak day), then a coach voice quote in italic display.
//
// Mirrors `WeekRecapCard` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/plan_mock.dart';
import '../../theme/vf_theme.dart';
import 'plan_typography.dart';
import '../../theme/app_colors.dart';
class WeekRecapCard extends StatelessWidget {
  const WeekRecapCard({super.key, required this.week});

  final PlanWeek week;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.bgInverse,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.borderDark),
        ),
        child: Stack(
          children: [
            // Yellow radial wash, top-left.
            Positioned(
              top: -40,
              left: -40,
              child: IgnorePointer(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.yellow.withValues(alpha: 0.16),
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
                // Stat trio.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _RecapStat(label: 'Buổi tập', value: '${week.completed}'),
                    const SizedBox(width: 22),
                    Container(
                      width: 1,
                      height: 28,
                      color: c.borderDark,
                      margin: const EdgeInsets.only(bottom: 4),
                    ),
                    const SizedBox(width: 22),
                    _RecapStat(
                      label: 'Form TB',
                      value: '${week.avgForm ?? 0}',
                      unit: '%',
                      yellow: true,
                    ),
                    const SizedBox(width: 22),
                    Container(
                      width: 1,
                      height: 28,
                      color: c.borderDark,
                      margin: const EdgeInsets.only(bottom: 4),
                    ),
                    const SizedBox(width: 22),
                    _RecapStat(
                      label: 'Đỉnh',
                      value: week.bestDay ?? '—',
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Coach voice quote.
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
                          const CoachMark(),
                          const SizedBox(width: 8),
                          PlanEyebrow(
                            'Huấn luyện viên ghi',
                            size: 9,
                            letterSpacing: 1.6,
                            color: c.yellow,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      PlanP(
                        week.recap ?? '',
                        dark: true,
                        italic: true,
                        size: 16,
                        letterSpacing: -0.3,
                        height: 1.4,
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

class _RecapStat extends StatelessWidget {
  const _RecapStat({
    required this.label,
    required this.value,
    this.unit,
    this.yellow = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? unit;
  final bool yellow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PlanEyebrow(label, size: 9, letterSpacing: 1.6, dark: true),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: compact ? 22 : 32,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: compact ? -1 : -1.5,
                height: compact ? 0.95 : 0.9,
                color: yellow ? c.yellow : c.invInk,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
            if (unit != null)
              Text(
                unit!,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.invInkSoft,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
