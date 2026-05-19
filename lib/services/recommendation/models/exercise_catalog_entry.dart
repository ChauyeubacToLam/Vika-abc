// One row from the Supabase `exercise_catalog` table. Loaded by
// ExerciseRepository, consumed by the RecommendationEngine pipeline.
//
// Not to be confused with `ExerciseDefinition` in lib/models/ —
// that's the in-memory UI + factory wrapper carrying Color/IconData
// and the `ExerciseBase Function() createExercise` factory.
// Both share the same `id` field. After picking a catalog entry,
// look up the matching ExerciseDefinition via
// `lookupExerciseDefinition()` to get UI metadata + the factory.

class ExerciseCatalogEntry {
  const ExerciseCatalogEntry({
    required this.id,
    required this.vietnameseName,
    required this.englishName,
    required this.fork,
    required this.bodyRegions,
    required this.muscleGroups,
    required this.difficultyTier,
    required this.goalFit,
    required this.painSafe,
    required this.painContraindicated,
    required this.isFormChecked,
    required this.isCorrective,
    required this.correctiveFor,
    this.classKey,
    this.videoUrl,
    this.baseReps,
    this.baseSeconds,
    this.maxRepsBeginner,
    this.maxRepsIntermediate,
    this.maxRepsAdvanced,
    this.maxSecondsBeginner,
    this.maxSecondsIntermediate,
    this.maxSecondsAdvanced,
    this.progressionFrom,
    this.progressionTo,
    this.metadata = const {},
  });

  // ── Identity ──
  final String id;
  final String vietnameseName;
  final String englishName;

  // ── Routing ──
  /// 'home' | 'yoga' | 'both'
  final String fork;

  /// e.g. ['lower_body'], ['upper_body'], ['core'], ['full_body'].
  /// Used by Stage 1 slot filter (slot.acceptedBodyRegions).
  final List<String> bodyRegions;

  /// Fine-grained tags. Used by optional slot.acceptedMuscleGroups
  /// filter + MMR similarity. e.g. ['quads', 'glutes'].
  final List<String> muscleGroups;

  /// 1 = beginner, 2 = intermediate, 3 = advanced.
  /// Matches profiles.fitness_level once mapped via levelToTier().
  final int difficultyTier;

  // ── Scoring ──
  /// Per-goal fit map, e.g.
  /// {'strength': 0.90, 'health': 0.85, 'pain': 0.55, 'energy': 0.80}.
  /// Keys are the goal categories ScoringService scores against.
  /// If profiles.why_primary uses different IDs (pain/confidence/
  /// energy/health), map at ScoringService layer, NOT here.
  final Map<String, double> goalFit;

  // ── Safety ──
  /// Pain areas this exercise actively benefits. Scoring bonus only,
  /// NOT a filter — pain-area users still get scored against other
  /// exercises too.
  final List<String> painSafe;

  /// Pain areas where this exercise MUST NOT be prescribed.
  /// Hard filter at Stage 1. NEVER relaxed by fallback chain.
  /// Safety boundary.
  final List<String> painContraindicated;

  // ── Pipeline flags ──
  /// True when a Dart class with real-time camera coaching exists.
  /// Form-checked exercises are the prescription path; video-only
  /// library exercises (40 yoga + 40 HW post-launch) live in browse
  /// only and are filtered out of recommendations.
  final bool isFormChecked;

  /// Corrective exercises route through the 5th-slot path only,
  /// not main prescription. Filtered out at Stage 1 unless the
  /// corrective slot is explicitly requested.
  final bool isCorrective;

  /// Which detected issues this corrects when isCorrective=true.
  /// e.g. ['knee_valgus']. Empty for non-corrective entries.
  final List<String> correctiveFor;

  // ── Bridge to existing registry ──
  /// Maps to ExerciseDefinition.id in lib/models/exercise_definition.dart.
  /// Currently equal to `id` for every v1 entry. Distinct field reserved
  /// for the future case where one Dart class backs multiple catalog
  /// variants (e.g. squat_assessment vs squat both → Squat class).
  final String? classKey;

  /// Demo video URL on Vika CDN. Null for v1 form-checked exercises
  /// — users get real-time camera coaching instead of demo video.
  final String? videoUrl;

  // ── Default volume (overridden per-week by ProgressionRules) ──
  /// Default rep count for rep-based exercises. Null for hold-based.
  final int? baseReps;

  /// Default hold duration in seconds for hold-based / yoga.
  /// Null for rep-based.
  final int? baseSeconds;

  /// Tier-specific rep ceilings. Null = no cap.
  /// When hit, signals "ready for harder variant" via progression_to walk.
  final int? maxRepsBeginner;
  final int? maxRepsIntermediate;
  final int? maxRepsAdvanced;

  /// Tier-specific hold ceilings. Same semantic.
  final int? maxSecondsBeginner;
  final int? maxSecondsIntermediate;
  final int? maxSecondsAdvanced;

  // ── Progression links (v1.5+ feature, populated for reference) ──
  /// Easier variant this exercise progresses FROM.
  /// e.g. cobra.progressionFrom = 'sphinx'. Null in v1 seed,
  /// backfill when progression logic ships.
  final String? progressionFrom;

  /// Harder variant this exercise progresses TO.
  final String? progressionTo;

  // ── Forward compatibility ──
  /// Catch-all JSONB. v1 seed rows have:
  ///   {seed_version: '1.0-provisional', source: 'claude-2026-05-14',
  ///    evidence_anchor: study_id_or_null}
  /// Refresh provisional rows via:
  ///   WHERE metadata->>'seed_version' = '1.0-provisional'
  final Map<String, dynamic> metadata;

  /// Parses a row returned by Supabase SELECT.
  factory ExerciseCatalogEntry.fromSupabase(Map<String, dynamic> row) {
    return ExerciseCatalogEntry(
      id: row['id'] as String,
      vietnameseName: row['vietnamese_name'] as String,
      englishName: row['english_name'] as String,
      fork: row['fork'] as String,
      bodyRegions: _stringList(row['body_regions']),
      muscleGroups: _stringList(row['muscle_groups']),
      difficultyTier: (row['difficulty_tier'] as num).toInt(),
      goalFit: _doubleMap(row['goal_fit']),
      painSafe: _stringList(row['pain_safe']),
      painContraindicated: _stringList(row['pain_contraindicated']),
      isFormChecked: row['is_form_checked'] as bool,
      isCorrective: row['is_corrective'] as bool,
      correctiveFor: _stringList(row['corrective_for']),
      classKey: row['class_key'] as String?,
      videoUrl: row['video_url'] as String?,
      baseReps: (row['base_reps'] as num?)?.toInt(),
      baseSeconds: (row['base_seconds'] as num?)?.toInt(),
      maxRepsBeginner: (row['max_reps_beginner'] as num?)?.toInt(),
      maxRepsIntermediate: (row['max_reps_intermediate'] as num?)?.toInt(),
      maxRepsAdvanced: (row['max_reps_advanced'] as num?)?.toInt(),
      maxSecondsBeginner: (row['max_seconds_beginner'] as num?)?.toInt(),
      maxSecondsIntermediate:
          (row['max_seconds_intermediate'] as num?)?.toInt(),
      maxSecondsAdvanced: (row['max_seconds_advanced'] as num?)?.toInt(),
      progressionFrom: row['progression_from'] as String?,
      progressionTo: row['progression_to'] as String?,
      metadata: (row['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

/// Supabase returns TEXT[] columns as dynamic lists. Plain string-list casts
/// throw because the runtime type is dynamic-list;
/// you need element-by-element cast via `.cast<String>()`.
List<String> _stringList(dynamic value) {
  if (value == null) return const [];
  return (value as List).cast<String>();
}

/// JSONB number values come back as `num` (int when the literal had
/// no decimal, double when it did). Force everything to double so
/// downstream scoring math doesn't trip over int/double type errors.
Map<String, double> _doubleMap(dynamic value) {
  if (value == null) return const {};
  final raw = (value as Map).cast<String, dynamic>();
  return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
}
