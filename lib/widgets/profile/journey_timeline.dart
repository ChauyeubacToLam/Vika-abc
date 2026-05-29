// JourneyTimeline — vertical milestone ribbon. Reads as the user's
// own story from the day they joined Vika to today.
//
// Each milestone:
//   ●━━━━━━━━━━━━━ DATE — Title
//   ┃               Italic subtitle that explains what happened.
//   ┃
//   ●━━━━━━━━━━━━━ Next milestone…
//
// The TODAY entry gets a special treatment — yellow ring around the
// dot, a slim "HÔM NAY" eyebrow chip on the right, and a stronger
// title. Everything above today is "passed", below would be locked
// (none in mock — kept for future expansion).

import 'package:flutter/material.dart';

import '../../data/profile_mock.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

class JourneyTimeline extends StatelessWidget {
  const JourneyTimeline({super.key, required this.milestones});

  final List<JourneyMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < milestones.length; i++)
            _MilestoneRow(
              milestone: milestones[i],
              isFirst: i == 0,
              isLast: i == milestones.length - 1,
            ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.isFirst,
    required this.isLast,
  });

  final JourneyMilestone milestone;
  final bool isFirst;
  final bool isLast;

  IconData get _kindIcon {
    return switch (milestone.kind) {
      JourneyKind.join => Icons.flag_rounded,
      JourneyKind.milestone => Icons.workspace_premium_rounded,
      JourneyKind.pr => Icons.emoji_events_rounded,
      JourneyKind.formScore => Icons.center_focus_strong_rounded,
      JourneyKind.today => Icons.fiber_manual_record_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final isToday = milestone.kind == JourneyKind.today;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical ribbon on the left: hairline + dot.
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Top half-line (faded at the very first row).
                Container(
                  width: 2,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isFirst ? Colors.transparent : c.border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                // Dot — yellow + glow for today, ink otherwise.
                Container(
                  width: isToday ? 22 : 16,
                  height: isToday ? 22 : 16,
                  decoration: BoxDecoration(
                    color: isToday ? c.yellow : c.bgRaised,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isToday ? c.yellow : c.borderHi,
                      width: isToday ? 2 : 1.5,
                    ),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: c.yellow.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _kindIcon,
                    size: isToday ? 10 : 9,
                    color: isToday ? c.yellowInk : c.inkSoft,
                  ),
                ),
                // Bottom continuation line (skipped for the last row).
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: isLast ? Colors.transparent : c.border,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Content card.
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 6,
                bottom: isLast ? 6 : 18,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: isToday ? c.bgRaised : c.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isToday ? c.yellow.withValues(alpha: 0.3) : c.border,
                    width: isToday ? 1.2 : 1,
                  ),
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                            color: c.yellow.withValues(alpha: 0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          milestone.date,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: isToday ? c.yellow : c.inkFaint,
                            fontFeatures: VikaIvoryMain.tabularFigures,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.yellow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'HÔM NAY',
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: c.yellowInk,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isToday ? '${milestone.title}.' : milestone.title,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: isToday ? 18 : 15,
                        fontWeight: FontWeight.w800,
                        fontStyle:
                            isToday ? FontStyle.italic : FontStyle.normal,
                        letterSpacing: -0.5,
                        height: 1.1,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      milestone.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                        color: c.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
