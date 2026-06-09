// Streak model: the unit is consecutive ACTIVE WEEKS (an ISO week, local tz,
// with >= 1 completed workout session). It surfaces everywhere as a scaling
// DURATION label — never a raw day or week count.
//
// This file is the single source of streak copy + thresholds. Every display
// (Home vitals, Profile, the summary trophy, the milestone hint) reads
// [streakTierLabel]; every milestone check reads [isStreakMilestoneWeek] /
// [nextStreakMilestoneWeek].

/// Tier ladder thresholds in consecutive active weeks. Past 52 a new tier
/// fires every additional year (104, 156, …) — see [isStreakMilestoneWeek].
const List<int> kStreakTierThresholds = [1, 2, 4, 8, 12, 26, 52];

/// Duration label for [weeks] consecutive active weeks: the label of the
/// HIGHEST tier <= [weeks]. Empty string for 0 (or negative) — no streak,
/// callers hide the display. Copy is FIXED.
///
///   1 → '1 tuần'   2 → '2 tuần'   4 → '1 tháng'   8 → '2 tháng'
///   12 → '1 quý'   26 → 'nửa năm' 52 → '1 năm'    +52 → '{n} năm'
String streakTierLabel(int weeks) {
  if (weeks < 1) return '';
  if (weeks >= 52) return '${weeks ~/ 52} năm';
  if (weeks >= 26) return 'nửa năm';
  if (weeks >= 12) return '1 quý';
  if (weeks >= 8) return '2 tháng';
  if (weeks >= 4) return '1 tháng';
  if (weeks >= 2) return '2 tuần';
  return '1 tuần'; // weeks >= 1
}

/// True when [weeks] is a milestone threshold: one of the fixed tiers, or a
/// whole number of years past the first ({1,2,4,8,12,26,52,104,156,…}).
bool isStreakMilestoneWeek(int weeks) {
  if (weeks < 1) return false;
  if (kStreakTierThresholds.contains(weeks)) return true;
  return weeks % 52 == 0; // every additional year beyond 52
}

/// Smallest milestone threshold strictly greater than [weeks]. Always defined
/// — past the final fixed tier it returns the next whole year.
int nextStreakMilestoneWeek(int weeks) {
  for (final t in kStreakTierThresholds) {
    if (t > weeks) return t;
  }
  return ((weeks ~/ 52) + 1) * 52;
}
