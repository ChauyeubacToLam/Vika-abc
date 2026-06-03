/// Candidate fault that can headline the frozen session coach note.
class FaultCandidate {
  /// Persisted exercise identity used for cross-exercise grouping.
  final String exerciseId;

  /// Display name for the exercise that emitted this fault.
  final String exerciseName;

  /// Form score of the emitting exercise; lower scores rank earlier.
  final int exerciseFormScore;

  /// Fault count key emitted by the exercise report builder.
  final String faultKey;

  /// Pooled fault count divided by pooled reps for this exercise.
  final double rate;

  /// True when this fault maps to one of the user's active pain areas.
  final bool isPainLinked;

  /// Intra-exercise judgment that this metric is critical for this exercise.
  final bool isCritical;

  /// Stable order among emitted candidates after builder filtering.
  final int sortIndex;

  /// Coach copy describing what to watch in the completed session.
  final String watchCopy;

  /// Forward-looking cue for the next session.
  final String nextCopy;

  const FaultCandidate({
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseFormScore,
    required this.faultKey,
    required this.rate,
    required this.isPainLinked,
    required this.isCritical,
    required this.sortIndex,
    required this.watchCopy,
    required this.nextCopy,
  });
}
