import 'plan.dart';

// Internal output of RecommendationEngine.generatePlan(). Wraps the
// user-facing Plan with the bookkeeping fields RecommendationLogger
// needs to write a recommendations_log row.
//
// External callers (UserProgramService, UI) only need Plan.
// RecommendationResult is engine-internal — flows engine → logger,
// nothing else consumes it.

class RecommendationResult {
  const RecommendationResult({
    required this.plan,
    required this.trigger,
    required this.algorithmVersion,
    required this.rngSeed,
    required this.parameters,
    required this.userSnapshot,
  });

  /// The prescription itself — the only piece UI callers care about.
  final Plan plan;

  /// 'onboarding' | 'reassessment' | 'profile_change'.
  /// Persisted to recommendations_log.trigger; CHECK constraint
  /// enforces these three values at the DB layer.
  final String trigger;

  /// Manually-bumped const in recommendation_engine.dart whenever
  /// parameters or pipeline shape changes. Lets us A/B test and
  /// retroactively segment historical plans by algorithm version.
  final String algorithmVersion;

  /// Seed used for StochasticSampler.stableHash. Same seed + same
  /// inputs = same plan (reproducibility). Useful for debugging and
  /// for v2 bandit training.
  final String rngSeed;

  /// {K, tau, lambda, cooldownWindowSessions, weekOneTemperature}
  /// at generation time. Lets us know which knob values produced
  /// which plans when we tune in production.
  final Map<String, dynamic> parameters;

  /// Profile state at generation time. Stored so v1.5 ML training
  /// knows what the algorithm SAW, not the user's current state
  /// (which may have drifted). Shape per spec section 3.2:
  /// {fitness_level, fork, goals, why_primary, active_pain_areas,
  ///  detected_issues, training_duration}.
  final Map<String, dynamic> userSnapshot;
}
