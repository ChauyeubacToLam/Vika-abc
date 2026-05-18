// lib/services/recommendation/scoring.dart
//
// Stage 2 of the RecommendationEngine pipeline: computes a weighted
// fit score for an ExerciseCatalogEntry given a user's state.
//
// CONTRACT:
//   - Pure function. No side effects. No async. Deterministic.
//   - Inputs are explicit primitive lists/strings, NOT a UserProfile
//     object. UserProfile arrives during the SharedPrefs→Supabase
//     read-path refactor (Layer 3); decoupling lets us land scoring
//     before that refactor settles.
//   - Returns score in [0.0, 1.0]. Higher = better fit.
//   - Caller guarantees (enforced upstream at Stage 1, do NOT re-check
//     in this file):
//       * exercise.painContraindicated ∩ activePainAreas == ∅
//       * exercise passes the slot's body region / muscle filters
//       * exercise.isFormChecked == true (if main slot, not corrective)
//
// GOAL KEYS:
//   goalKey is the S03 onboarding selection (OnboardingData.goal),
//   one of {'health', 'body', 'strength', 'flexible'}. These map
//   directly to ExerciseCatalogEntry.goalFit keys — no translation.
//   `why_primary` (S02) is consumed elsewhere (S14 copy, S05 fork)
//   and does NOT flow into scoring.

import 'models/exercise_catalog_entry.dart';

// ═══════════════════════════════════════════════════════════════
// TUNABLE KNOBS — defaults from spec, override-able at engine wiring
// ═══════════════════════════════════════════════════════════════

/// Component weights. Sum to 1.0 so the weighted score is naturally
/// in [0.0, 1.0] range.
///
/// Spec defaults — tune in production based on session feedback.
/// Currently provisional; PT review should sign off before launch.
const double _wGoal = 0.45;
const double _wLevel = 0.25;
const double _wPain = 0.15;
const double _wCooldown = 0.15;

/// How many recent sessions count toward cooldown. Exercises NOT in
/// the most-recent _cooldownWindow get full freshness = 1.0.
const int _cooldownWindow = 6;

/// Fallback goal lookup when caller passes an unrecognized goalKey.
/// 'health' is the safest middle-of-road default across exercises.
const String _defaultGoal = 'health';

// ═══════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════

/// Returns score in [0.0, 1.0]. Higher = better fit for this user.
double score({
  required ExerciseCatalogEntry exercise,
  required String fitnessLevel,              // 'beginner'|'intermediate'|'advanced'
  required String goalKey,                   // 'health'|'body'|'strength'|'flexible'
  required List<String> activePainAreas,
  required List<String> recentExerciseIds,   // most-recent-first
}) {
    final g = _goalComponent(exercise, goalKey);
    final l = _levelComponent(exercise.difficultyTier, fitnessLevel);
    final p = _painComponent(exercise.painSafe, activePainAreas);
    final c = _cooldownComponent(exercise.id, recentExerciseIds);
  
  // Step 2: Weighted sum.
  return _wGoal * g + _wLevel * l + _wPain * p + _wCooldown * c;

}

// ═══════════════════════════════════════════════════════════════
// COMPONENTS — each is a pure helper that returns [0.0, 1.0]
// ═══════════════════════════════════════════════════════════════

/// Goal-fit. Direct lookup into exercise.goalFit[goalKey].
///
/// TWO-STAGE FALLBACK:
///   1. If goalKey is missing from goalFit (defensive — shouldn't fire
///      in practice since seed has all 4 keys on every row), fall back
///      to the 'health' value.
///   2. If 'health' is also missing (catastrophic data error), return
///      a neutral 0.5 so scoring NEVER throws.
double _goalComponent(ExerciseCatalogEntry exercise, String goalKey) {
    final value = exercise.goalFit[goalKey];
    if (value != null) return value;
    return exercise.goalFit[_defaultGoal] ?? 0.5;
}

/// Level-match curve. Exact tier match = 1.0, off by 1 tier = 0.7,
/// off by 2+ = 0.0.
///
/// Lets near-level exercises through with a modest penalty so the
/// pool doesn't collapse when library is sparse at a level. Blocks
/// gross mismatches (beginner facing advanced) from scoring at all.
double _levelComponent(int exerciseTier, String fitnessLevel) {
    final userTier = _levelToTier(fitnessLevel);
    final diff = (exerciseTier - userTier).abs();
    if (diff == 0) return 1.0;
    if (diff == 1) return 0.7;
    return 0.0;
}

/// Pain-safety BONUS — rewards exercises that ACTIVELY benefit the
/// user's pain areas. Contraindication is filtered out at Stage 1,
/// so this function only ever sees safe exercises; the question
/// here is "does it ALSO help".
///
/// LOGIC:
///   activePainAreas.isEmpty
///       → 0.5 (neutral; user has no pain to bias toward/against)
///   activePainAreas has N items
///       → (count of exercisePainSafe ∩ activePainAreas) / N
///         e.g. user {back, hip}, ex covers {back}     → 0.5
///         e.g. user {back, hip}, ex covers {back,hip} → 1.0
///         e.g. user {back, hip}, ex covers {}         → 0.0
///
/// NOTE on the no-pain-area case: returning 0.5 means every exercise
/// gets the same +0.075 baseline contribution from this component;
/// that's noise to RANKING but adds a tiny constant. Acceptable for
/// v1; v2 could dynamically re-normalize weights when N=0.
double _painComponent(
    List<String> exercisePainSafe, List<String> activePainAreas) {
    if (activePainAreas.isEmpty) return 0.5;
    final overlap = activePainAreas.where(exercisePainSafe.contains).length;
    return overlap / activePainAreas.length;
}

/// Cooldown FRESHNESS (note: NOT penalty; we invert here so that
/// 1.0 = fully fresh, 0.0 = just did it, and the weighted sum stays
/// in [0, 1]).
///
/// recentExerciseIds is MOST-RECENT-FIRST, length up to _cooldownWindow.
///
/// LOGIC:
///   exercise.id not in recentExerciseIds
///       → 1.0 (beyond cooldown window, fully fresh)
///   exercise.id at index i (0-based)
///       → i / (_cooldownWindow - 1)
///         i=0 (just done):   0.0
///         i=1:               0.2
///         i=5 (edge of window): 1.0
double _cooldownComponent(String exerciseId, List<String> recentExerciseIds) {
    final i = recentExerciseIds.indexOf(exerciseId);
    if (i == -1) return 1.0;
    return (i / (_cooldownWindow - 1)).clamp(0.0, 1.0);
}

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════

/// Maps the profiles.fitness_level string to ExerciseCatalogEntry
/// .difficultyTier int (1/2/3).
///
/// Defaults to 2 (intermediate) on unknown input. Safer than 1
/// because tier-1 AND tier-3 exercises are reachable via the 0.7
/// off-by-1 path; a 1-default would zero out all tier-3 exercises.
int _levelToTier(String fitnessLevel) {
    switch (fitnessLevel) {
      case 'beginner':     return 1;
      case 'intermediate': return 2;
      case 'advanced':     return 3;
      default:             return 2;
    }
}