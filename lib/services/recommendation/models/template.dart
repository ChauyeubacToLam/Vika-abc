import 'slot.dart';

// Compile-time const template definition. The 8 launch templates
// live in lib/services/recommendation/templates.dart as a const Map.
//
// ArchetypeRouter selects ONE template per user based on (fork, goal).
// The selected template's slots define what the RecommendationEngine
// fills each session.
//
// v4.3 ADDITIONS:
//   - numPhases / weeksPerPhase / includeDeloadAtEnd: scalable block
//     structure. v1 default: 2 phases x 3 weeks + 1 deload = 7 weeks.
//   - defaultRestSecondsRep / defaultRestSecondsHold: rest is constant
//     within a block, varies by template archetype.
//   - deloadName: user-facing label for the deload week.

class Template {
  const Template({
    required this.key,
    required this.fork,
    required this.goal,
    required this.vietnameseName,
    required this.slots,
    required this.phaseNames,
    required this.deloadName,
    required this.numPhases,
    required this.weeksPerPhase,
    required this.includeDeloadAtEnd,
    required this.defaultRestSecondsRep,
    required this.defaultRestSecondsHold,
  });

  /// Stable identifier persisted to recommendations_log.template_key.
  /// e.g. 'home_strength', 'yoga_pain'.
  final String key;

  /// 'home' | 'yoga'. No 'both' for templates — every user is in
  /// exactly one fork. ExerciseCatalogEntry.fork='both' just means
  /// the exercise can appear in either fork's templates.
  final String fork;

  /// Goal key matching the goalFit vocabulary in ExerciseCatalogEntry
  /// and scoring.dart. Values: 'health' | 'body' | 'strength' | 'flexible'.
  /// Maps directly from the S03 onboarding selection.
  final String goal;

  /// User-facing template display name, e.g. 'Tập tạ — Khoẻ hơn'.
  /// Shown in places where users see "your program is X".
  final String vietnameseName;

  /// Ordered list of slots. Each session in the plan fills these
  /// slots in order. Typical length 4.
  final List<Slot> slots;

  /// One name per PHASE. Length must equal numPhases.
  /// v1 default: ['Nền tảng', 'Phát triển']
  ///
  /// Indexed at generation time by `WeekPlan.phaseNumber - 1` and
  /// snapshotted onto each WeekPlan.phaseName.
  final List<String> phaseNames;

  /// User-facing label for the deload week. v1 default: 'Phục hồi'.
  /// Snapshotted onto WeekPlan.phaseName when isDeloadWeek = true.
  final String deloadName;

  /// Number of progression phases in this program (excluding deload).
  /// v1 default: 2. Configurable per template for v2+ custom plans.
  final int numPhases;

  /// Weeks per phase. Same value for all phases (uniform structure).
  /// v1 default: 3. If variable-length phases are needed later,
  /// change to a list of integers with one entry per phase.
  final int weeksPerPhase;

  /// Append a deload week at the end of the program. Almost always
  /// true. v1 default: true. Total weeks =
  /// numPhases * weeksPerPhase + (includeDeloadAtEnd ? 1 : 0).
  final bool includeDeloadAtEnd;

  /// Constant rest seconds between sets for rep-based exercises.
  /// Varies by template archetype (Strength = 75, Body/Health = 60, etc.).
  /// Does NOT change across phases.
  final int defaultRestSecondsRep;

  /// Constant rest seconds between rounds for hold-based exercises.
  /// Yoga conventions: 30s default, 45s for strength-focused yoga.
  final int defaultRestSecondsHold;

  int get progressionWeeks => numPhases * weeksPerPhase;
  int get totalWeeks => progressionWeeks + (includeDeloadAtEnd ? 1 : 0);
}
