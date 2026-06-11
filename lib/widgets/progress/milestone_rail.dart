// MilestoneRail — the CỘT MỐC section. A horizontal rail of tiered
// achievement badges: rungs you've already touched (silver pewter medallions,
// deliberately understated — NOT the reserved yellow) followed by the next
// locked rung in each category as a target to chase (dimmed, with its label +
// threshold). Never blank: a fresh account reads as all-locked targets.
//
// Unlock state is computed off real session history in
// `SessionPersistence.deriveUnlockedMilestonesForTest`; this widget is pure
// presentation. Gold/platinum unlocked treatment is post-launch — at launch
// only silver rungs are reachable, so unlocked badges all read pewter for now.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/milestones.dart';
import '../../theme/app_colors.dart';
import '../../theme/vf_theme.dart';

/// Selects which rungs the rail shows: per category (in render order) every
/// unlocked rung by threshold, then the single next locked rung as the chase
/// target. Always yields at least one rung per category, so the rail is never
/// blank. Pure — handy to unit-test alongside the deriver.
List<Milestone> selectRailMilestones(List<Milestone> all) {
  const order = [
    MilestoneCategory.streak,
    MilestoneCategory.sessions,
    MilestoneCategory.form,
    MilestoneCategory.consistency,
  ];
  final out = <Milestone>[];
  for (final cat in order) {
    final inCat = all.where((m) => m.category == cat).toList()
      ..sort((a, b) => a.threshold.compareTo(b.threshold));
    out.addAll(inCat.where((m) => m.unlocked));
    for (final m in inCat) {
      if (!m.unlocked) {
        out.add(m); // the next locked rung — the chase target
        break;
      }
    }
  }
  return out;
}

class MilestoneRail extends StatelessWidget {
  const MilestoneRail({
    super.key,
    required this.milestones,
    this.cardWidth = 158,
    this.gutter = 20,
  });

  /// The full catalog with unlock state resolved; the rail picks what to show.
  final List<Milestone> milestones;
  final double cardWidth;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final rungs = selectRailMilestones(milestones);
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 0),
        itemCount: rungs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) =>
            _MilestoneCard(milestone: rungs[i], width: cardWidth),
      ),
    );
  }
}

/// Eyebrow label per category.
String _categoryLabel(MilestoneCategory c) => switch (c) {
      MilestoneCategory.streak => 'CHUỖI',
      MilestoneCategory.sessions => 'BUỔI TẬP',
      MilestoneCategory.form => 'FORM',
      MilestoneCategory.consistency => 'ĐỀU ĐẶN',
    };

IconData _categoryIcon(MilestoneCategory c) => switch (c) {
      MilestoneCategory.streak => Icons.local_fire_department_rounded,
      MilestoneCategory.sessions => Icons.fitness_center_rounded,
      MilestoneCategory.form => Icons.verified_rounded,
      MilestoneCategory.consistency => Icons.event_available_rounded,
    };

class _MilestoneCard extends StatefulWidget {
  const _MilestoneCard({required this.milestone, required this.width});
  final Milestone milestone;
  final double width;

  @override
  State<_MilestoneCard> createState() => _MilestoneCardState();
}

class _MilestoneCardState extends State<_MilestoneCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final m = widget.milestone;
    final unlocked = m.unlocked;

    // Pewter medallion — a muted neutral, NOT the reserved yellow. Built from
    // ink tones so it stays in the Ivory palette.
    final medallionFill =
        unlocked ? c.inkSoft : c.ink.withValues(alpha: 0.05);
    final medallionIcon = unlocked ? c.bgRaised : c.inkGhost;

    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Opacity(
          // Locked rungs are dimmed as targets to chase.
          opacity: unlocked ? 1.0 : 0.55,
          child: Container(
            width: widget.width,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: c.bgRaised,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: c.border),
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: c.ink.withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: medallionFill,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        unlocked
                            ? _categoryIcon(m.category)
                            : Icons.lock_rounded,
                        size: 18,
                        color: medallionIcon,
                      ),
                    ),
                    const Spacer(),
                    if (unlocked)
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: c.inkSoft),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _categoryLabel(m.category),
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: c.inkFaint,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.4,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 22,
                  height: 2,
                  decoration: BoxDecoration(
                    color: unlocked ? c.inkSoft : c.border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const Spacer(),
                Text(
                  unlocked
                      ? (m.unlockedOn != null
                          ? 'Đạt ${m.unlockedOn}'
                          : 'Đã chạm tới')
                      : 'Mục tiêu kế tiếp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.1,
                    color: unlocked ? c.inkSoft : c.inkFaint,
                    fontFeatures: VikaIvoryMain.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
