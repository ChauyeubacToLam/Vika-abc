// ExerciseFormBar — single-row visualization of one exercise's form score
// inside a done-day timeline card. Name on the left, horizontal bar in the
// middle, % numeral on the right.
//
// Color-codes the bar by form score:
//   form >= 80 → yellow (strong)
//   form < 65  → attention orange (needs work)
//   else       → ink (default)
//
// Mirrors `ExerciseFormBar` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';
import '../../data/plan_mock.dart';
import '../../theme/vf_theme.dart';
import '../../theme/app_colors.dart';

class ExerciseFormBar extends StatelessWidget {
  const ExerciseFormBar({super.key, required this.exercise});

  final PlanExercise exercise;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final f = exercise.form;
    final high = f >= 80;
    final low = f < 65;
    final barColor = high ? c.yellow : (low ? c.attention : c.ink);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              exercise.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: c.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 5,
                color: c.border,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (f.clamp(0, 100)) / 100,
                  child: Container(color: barColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 24,
            child: Text(
              '$f',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
                color: c.ink,
                fontFeatures: VikaIvoryMain.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
