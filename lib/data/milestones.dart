// Milestone ladder for the Progress-tab CỘT MỐC rail.
//
// A tiered, all-time achievement system: each rung is a (category, threshold)
// pair carrying a tier by magnitude. The full ladder is declared here so the
// rail can render locked rungs as targets to chase; unlock state is computed
// from real session history in `SessionPersistence.deriveUnlockedMilestones…`.
//
// Field shape cribbed from the now-dead `Achievement` model in profile_mock.

import 'package:flutter/foundation.dart';

/// What a milestone measures. Render order in the rail follows this order.
enum MilestoneCategory { streak, sessions, form, consistency }

/// Badge tier by magnitude. At launch only [silver] rungs are reachable on a
/// fresh account; [gold]/[platinum] unlocked styling is post-launch, but the
/// field exists now so those rungs light up later with no rework.
enum MilestoneTier { silver, gold, platinum }

@immutable
class Milestone {
  const Milestone({
    required this.category,
    required this.threshold,
    required this.tier,
    required this.label,
    this.unlocked = false,
    this.unlockedOn,
  });

  final MilestoneCategory category;

  /// Numeric bar for streak/sessions/form (days / count / raw form score).
  /// For [MilestoneCategory.consistency] this is a span sentinel — 1 = a
  /// Mon–Sun week, 2 = a calendar month — used only for stable ordering.
  final int threshold;

  final MilestoneTier tier;

  /// Short VN label, e.g. "Chuỗi 7 ngày", "10 buổi", "Form 90".
  final String label;

  final bool unlocked;

  /// 'd/M' date the threshold was first crossed, when derivable; null when
  /// locked or not derivable. Only meaningful when [unlocked].
  final String? unlockedOn;

  Milestone asUnlocked(String? on) => Milestone(
        category: category,
        threshold: threshold,
        tier: tier,
        label: label,
        unlocked: true,
        unlockedOn: on,
      );
}

/// Consistency span sentinels (stored in [Milestone.threshold]).
const int kConsistencyWeek = 1;
const int kConsistencyMonth = 2;

/// The complete ladder. All rungs defined now; tier follows magnitude.
const List<Milestone> milestoneCatalog = [
  // ─── Streak (consecutive local days with a completed session) ───
  Milestone(
      category: MilestoneCategory.streak,
      threshold: 3,
      tier: MilestoneTier.silver,
      label: 'Chuỗi 3 ngày'),
  Milestone(
      category: MilestoneCategory.streak,
      threshold: 7,
      tier: MilestoneTier.silver,
      label: 'Chuỗi 7 ngày'),
  Milestone(
      category: MilestoneCategory.streak,
      threshold: 14,
      tier: MilestoneTier.gold,
      label: 'Chuỗi 14 ngày'),
  Milestone(
      category: MilestoneCategory.streak,
      threshold: 30,
      tier: MilestoneTier.gold,
      label: 'Chuỗi 30 ngày'),
  Milestone(
      category: MilestoneCategory.streak,
      threshold: 60,
      tier: MilestoneTier.platinum,
      label: 'Chuỗi 60 ngày'),
  Milestone(
      category: MilestoneCategory.streak,
      threshold: 100,
      tier: MilestoneTier.platinum,
      label: 'Chuỗi 100 ngày'),

  // ─── Sessions (count of completed workout sessions) ───
  Milestone(
      category: MilestoneCategory.sessions,
      threshold: 1,
      tier: MilestoneTier.silver,
      label: 'Buổi đầu tiên'),
  Milestone(
      category: MilestoneCategory.sessions,
      threshold: 5,
      tier: MilestoneTier.silver,
      label: '5 buổi'),
  Milestone(
      category: MilestoneCategory.sessions,
      threshold: 10,
      tier: MilestoneTier.silver,
      label: '10 buổi'),
  Milestone(
      category: MilestoneCategory.sessions,
      threshold: 30,
      tier: MilestoneTier.gold,
      label: '30 buổi'),
  Milestone(
      category: MilestoneCategory.sessions,
      threshold: 50,
      tier: MilestoneTier.gold,
      label: '50 buổi'),
  Milestone(
      category: MilestoneCategory.sessions,
      threshold: 100,
      tier: MilestoneTier.platinum,
      label: '100 buổi'),

  // ─── Form (best raw_form_score in a single session) ───
  Milestone(
      category: MilestoneCategory.form,
      threshold: 80,
      tier: MilestoneTier.silver,
      label: 'Form 80'),
  Milestone(
      category: MilestoneCategory.form,
      threshold: 90,
      tier: MilestoneTier.gold,
      label: 'Form 90'),
  Milestone(
      category: MilestoneCategory.form,
      threshold: 100,
      tier: MilestoneTier.platinum,
      label: 'Form 100'),

  // ─── Consistency (every scheduled session done in a span) ───
  Milestone(
      category: MilestoneCategory.consistency,
      threshold: kConsistencyWeek,
      tier: MilestoneTier.silver,
      label: 'Tuần trọn vẹn'),
  Milestone(
      category: MilestoneCategory.consistency,
      threshold: kConsistencyMonth,
      tier: MilestoneTier.gold,
      label: 'Tháng trọn vẹn'),
];
