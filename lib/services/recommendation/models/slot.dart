// A slot is a placeholder within a Template that describes what KIND
// of exercise belongs here. Stage 1 of the pipeline filters
// ExerciseCatalogEntry candidates against the slot's constraints;
// Stage 2 scores survivors.
//
// Typical template has ~4 slots, e.g.:
//   - lower_body_strength
//   - upper_body_push
//   - core_stability
//   - hip_activation

class Slot {
  const Slot({
    required this.name,
    required this.acceptedBodyRegions,
    required this.difficultyRange,
    this.acceptedMuscleGroups,
  });

  /// Internal slot identifier. Persisted to exercise_sessions.slot_name
  /// for analytics. e.g. 'lower_body_strength'.
  final String name;

  /// Coarse filter (required). e.g. ['lower_body'].
  /// Must INTERSECT exercise.bodyRegions in Stage 1.
  final List<String> acceptedBodyRegions;

  /// Inclusive tier range. e.g. (min: 1, max: 3) accepts all levels.
  /// Stage 1 filter passes when:
  ///   exercise.difficultyTier >= range.min &&
  ///   exercise.difficultyTier <= range.max
  ///
  /// Using a NAMED record over the spec's positional (int, int)
  /// because slot.difficultyRange.min reads better than
  /// slot.difficultyRange.$1 at every call site.
  final ({int min, int max}) difficultyRange;

  /// Optional fine filter. When null, slot accepts any muscle group
  /// within the body region. When set, exercise.muscleGroups must
  /// INTERSECT this list. e.g. ['quads'] restricts a lower_body slot
  /// to squat/lunge, excludes glute_bridge.
  final List<String>? acceptedMuscleGroups;
}
