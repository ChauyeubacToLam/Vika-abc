// StreakWeekStrip — a recent-activity strip for the Progress "Chuỗi" section.
// One cell per week over the last N weeks, oldest on the left, current week on
// the right. A filled cell = an active week (>= 1 completed session); empty =
// a rest week. Because it shares the streak's active-week definition, the
// trailing run of filled cells IS the current streak — so it lives under the
// "Chuỗi" eyebrow with no relabel.
//
// Weekly cells (not the deleted daily bars). Premium Ivory tokens only: filled
// = warm ink with a gentle recency ramp (older weeks read softer), empty =
// a faint ink wash. No reserved yellow here.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class StreakWeekStrip extends StatelessWidget {
  const StreakWeekStrip({super.key, required this.weeks});

  /// Oldest-first; the last entry is the current week.
  final List<bool> weeks;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final n = weeks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 30,
          child: Row(
            children: [
              for (var i = 0; i < n; i++) ...[
                Expanded(child: _cell(c, filled: weeks[i], index: i, count: n)),
                if (i < n - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _axisLabel(c, '$n TUẦN TRƯỚC'),
            _axisLabel(c, 'TUẦN NÀY'),
          ],
        ),
      ],
    );
  }

  Widget _cell(
    VikaColors c, {
    required bool filled,
    required int index,
    required int count,
  }) {
    // Recency ramp: oldest week softest, current week fullest.
    final t = count <= 1 ? 1.0 : index / (count - 1);
    return Container(
      decoration: BoxDecoration(
        color: filled
            ? c.ink.withValues(alpha: 0.5 + t * 0.5)
            : c.inkFaint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _axisLabel(VikaColors c, String label) => Text(
        label,
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: c.inkFaint,
        ),
      );
}
