import 'exercise_catalog_entry.dart';

// Pairs an ExerciseCatalogEntry with its ScoringService output.
// Produced by Stage 2 (Score), consumed by Stage 3 (StochasticTopK)
// and Stage 4 (MMR). Persisted shape (id + score only) lives in
// plan_structure.sessions[].slots[].top_k_candidates.

class ScoredCandidate {
  const ScoredCandidate({
    required this.exercise,
    required this.score,
  });

  final ExerciseCatalogEntry exercise;

  /// Combined weighted score from ScoringService.score().
  /// Default weights: wGoal=0.45, wLevel=0.25, wPain=0.15, wCooldown=0.15.
  /// Range theoretically -1.0 to +1.0 (cooldown is subtractive); in
  /// practice [0.0, ~1.0] since cooldown only kicks in for recent.
  final double score;
}
