// FormWeekChart — small 7-day form-score bar chart shown next to the
// StreakRing on Home. Tabular numerals for the 78% headline, yellow
// "+6" delta pill, 7 vertical bars (today is yellow, others are
// borderHi), Mon→TODAY axis labels.
//
// Mirrors the inline 7-day chart in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../theme/vf_theme.dart';
import '../plan/plan_typography.dart';
import '../../theme/app_colors.dart';

class FormWeekChart extends StatelessWidget {
  const FormWeekChart({
    super.key,
    required this.todayPercent,
    required this.delta,
    required this.weekValues,
  });

  final int todayPercent; // e.g. 78
  final int delta; // e.g. 6 (positive)
  final List<int> weekValues; // length 7

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlanEyebrow('FORM 7 NGÀY', size: 9, letterSpacing: 1.6),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$todayPercent',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -2.5,
                  height: 0.9,
                  color: c.ink,
                  fontFeatures: VikaIvoryMain.tabularFigures,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '%',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.8,
                  color: c.inkSoft,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.yellowGhost,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '↑ +$delta',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: c.ink,
                      fontFeatures: VikaIvoryMain.tabularFigures,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 7 bars.
          SizedBox(
            height: 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < weekValues.length; i++) ...[
                  Expanded(
                    child: Container(
                      height: (weekValues[i].clamp(0, 100) / 100) * 28,
                      decoration: BoxDecoration(
                        color:
                            i == weekValues.length - 1 ? c.yellow : c.borderHi,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < weekValues.length - 1) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'T2',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: c.inkFaint,
                ),
              ),
              Text(
                'HÔM NAY',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
