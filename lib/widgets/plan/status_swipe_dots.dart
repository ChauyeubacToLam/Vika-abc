// StatusSwipeDots — the row of pager dots in the page hero. Status of each
// week is encoded in color (yellow=done, ink=current, ghost-outlined=future);
// the active week (currently swiped to) is encoded in width.
//
// Mirrors `StatusSwipeDots` in vika-main-app-ivory-v1.jsx.

import 'package:flutter/material.dart';

import '../../data/plan_mock.dart';
import '../../theme/app_colors.dart';

class StatusSwipeDots extends StatelessWidget {
  const StatusSwipeDots({
    super.key,
    required this.weeks,
    required this.activeWeek,
  });

  final List<PlanWeek> weeks;
  final int activeWeek; // 1-based to match the JSX

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final w in weeks) ...[
            _StatusDot(week: w, isActive: w.num == activeWeek),
            if (w != weeks.last) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.week, required this.isActive});

  final PlanWeek week;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final isDone = week.status == WeekStatus.done;
    final isCurrent = week.status == WeekStatus.current;
    final isFuture = !isDone && !isCurrent;

    final color = isDone
        ? c.yellow
        : isCurrent
            ? c.ink
            : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: isActive ? 22 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: isFuture
            ? Border.all(color: c.inkGhost, width: 1.5)
            : null,
      ),
    );
  }
}
