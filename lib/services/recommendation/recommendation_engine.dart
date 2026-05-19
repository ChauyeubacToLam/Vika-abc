import 'dart:math' as math;

import 'models/candidate.dart';
import 'models/exercise_catalog_entry.dart';
import 'models/plan.dart';
import 'models/recommendation_result.dart';
import 'models/slot.dart';
import 'models/template.dart';
import 'progression_rules.dart';
import 'scoring.dart' as scoring;
import 'stochastic_sampler.dart' as sampler;

const String kRecommendationAlgorithmVersion = 'v4.4.0';

class RecommendationRequest {
  const RecommendationRequest({
    required this.recommendationId,
    required this.userId,
    required this.template,
    required this.catalog,
    required this.fitnessLevel,
    required this.goalKey,
    required this.activePainAreas,
    required this.recentExerciseIds,
    required this.rngSeed,
    this.trigger = 'onboarding',
    this.sessionsPerWeek = 3,
    this.planScope = kPlanScopeFull,
    this.unlockedVariantByExerciseId = const {},
    this.carryOverByExerciseId = const {},
    this.userSnapshot = const {},
  });

  final String recommendationId;
  final String userId;
  final Template template;
  final List<ExerciseCatalogEntry> catalog;
  final String fitnessLevel;
  final String goalKey;
  final List<String> activePainAreas;
  final List<String> recentExerciseIds;
  final String rngSeed;
  final String trigger;
  final int sessionsPerWeek;
  final String planScope;
  final Map<String, String> unlockedVariantByExerciseId;
  final Map<String, CarryOverPerformance> carryOverByExerciseId;
  final Map<String, dynamic> userSnapshot;
}

class RecommendationEngine {
  const RecommendationEngine();

  RecommendationResult generatePlan(RecommendationRequest request) {
    if (request.catalog.isEmpty) {
      throw ArgumentError('Recommendation catalog is empty');
    }
    if (request.template.phaseNames.length != request.template.numPhases) {
      throw StateError(
        'Template ${request.template.key} phaseNames must match numPhases',
      );
    }

    final userTier = levelToTier(request.fitnessLevel);
    final catalogById = {
      for (final exercise in request.catalog) exercise.id: exercise,
    };

    final baseAssignments = _pickSessionAssignments(
      request: request,
      catalogById: catalogById,
    );

    final weeks = <WeekPlan>[];
    final totalWeeks = request.planScope == kPlanScopePhase1Only
        ? request.template.weeksPerPhase
        : request.template.totalWeeks;

    for (var week = 1; week <= totalWeeks; week++) {
      final progressionWeeks = request.template.progressionWeeks;
      final isDeload = request.template.includeDeloadAtEnd &&
          request.planScope == kPlanScopeFull &&
          week == progressionWeeks + 1;
      final position = isDeload
          ? (phase: request.template.numPhases + 1, weekInPhase: 1)
          : phaseAndWeek(
              absoluteWeek: week,
              weeksPerPhase: request.template.weeksPerPhase,
            );
      final phaseName = isDeload
          ? request.template.deloadName
          : request.template.phaseNames[position.phase - 1];

      weeks.add(
        WeekPlan(
          weekNumber: week,
          phaseNumber: position.phase,
          phaseName: phaseName,
          isDeloadWeek: isDeload,
          sessions: List.generate(
            request.sessionsPerWeek.clamp(1, 7).toInt(),
            (sessionIndex) => SessionPlan(
              sessionIndex: sessionIndex,
              slots: baseAssignments.map((assignment) {
                final exercise = catalogById[assignment.exerciseId];
                if (exercise == null) {
                  throw StateError(
                    'Picked exercise ${assignment.exerciseId} missing',
                  );
                }

                final volume = prescribeVolume(
                  exercise: exercise,
                  userTier: userTier,
                  absoluteWeek: week,
                  template: request.template,
                  carryOver: request.carryOverByExerciseId[exercise.id],
                );

                return SlotAssignment(
                  slotName: assignment.slotName,
                  exerciseId: assignment.exerciseId,
                  volume: volume,
                  score: assignment.score,
                  topKCandidates: assignment.topKCandidates,
                );
              }).toList(growable: false),
            ),
          ),
        ),
      );
    }

    final plan = Plan(
      recommendationId: request.recommendationId,
      userId: request.userId,
      templateKey: request.template.key,
      planScope: request.planScope,
      weeks: weeks,
      weeklyCheckInWeeks: [
        for (var week = 2; week <= totalWeeks; week++) week,
      ],
      endOfPlanRetest: request.planScope == kPlanScopeFull
          ? PlanRetest(
              afterWeekNumber: totalWeeks,
              vietnameseTitle: 'Kiểm tra lại thể lực',
              vietnameseDescription:
                  'Hoàn thành lại bài kiểm tra 5 rep để Vika cập nhật lộ trình tiếp theo.',
              exercises: const [
                RetestExercise(
                  exerciseId: 'squat_assessment',
                  vietnameseName: 'Squat 5 rep',
                  durationSeconds: 60,
                ),
                RetestExercise(
                  exerciseId: 'wall_pushup_assessment',
                  vietnameseName: 'Chống đẩy tường 5 rep',
                  durationSeconds: 60,
                ),
              ],
            )
          : null,
    );

    return RecommendationResult(
      plan: plan,
      trigger: request.trigger,
      algorithmVersion: kRecommendationAlgorithmVersion,
      rngSeed: request.rngSeed,
      parameters: {
        'mmr_lambda': 0.82,
        'sampler_top_n': 3,
        'sampler_epsilon': 0.3,
        'variant_unlock_streak': kDefaultVariantUnlockStreak,
        'progression_curve': 'linear_interpolation_to_tier_cap',
        'sessions_per_week': request.sessionsPerWeek,
      },
      userSnapshot: request.userSnapshot,
    );
  }

  List<SlotAssignment> _pickSessionAssignments({
    required RecommendationRequest request,
    required Map<String, ExerciseCatalogEntry> catalogById,
  }) {
    final selected = <ExerciseCatalogEntry>[];
    final assignments = <SlotAssignment>[];

    for (final slot in request.template.slots) {
      final candidates = _rankCandidatesForSlot(
        slot: slot,
        request: request,
        selected: selected,
      );
      if (candidates.isEmpty) {
        throw StateError(
          'No safe candidates for slot ${slot.name} in ${request.template.key}',
        );
      }

      final sampled = sampler.sample(
        candidates,
        '${request.rngSeed}:${request.template.key}:${slot.name}',
      );
      final exercise = _applyUnlockedVariant(
        picked: sampled.winner.exercise,
        request: request,
        catalogById: catalogById,
      );
      final score = exercise.id == sampled.winner.exercise.id
          ? sampled.winner.score
          : scoring.score(
              exercise: exercise,
              fitnessLevel: request.fitnessLevel,
              goalKey: request.goalKey,
              activePainAreas: request.activePainAreas,
              recentExerciseIds: request.recentExerciseIds,
            );

      selected.add(exercise);
      assignments.add(
        SlotAssignment(
          slotName: slot.name,
          exerciseId: exercise.id,
          volume: const VolumePrescription(
            sets: 1,
            reps: 1,
            restSeconds: 60,
          ),
          score: score,
          topKCandidates: sampled.topK
              .map((c) => (exerciseId: c.exercise.id, score: c.score))
              .toList(growable: false),
        ),
      );
    }

    return assignments;
  }

  List<ScoredCandidate> _rankCandidatesForSlot({
    required Slot slot,
    required RecommendationRequest request,
    required List<ExerciseCatalogEntry> selected,
  }) {
    var pool = request.catalog
        .where(
          (exercise) => _passesFilter(
            exercise: exercise,
            slot: slot,
            template: request.template,
            activePainAreas: request.activePainAreas,
          ),
        )
        .toList(growable: false);

    if (pool.isEmpty && slot.acceptedMuscleGroups != null) {
      pool = request.catalog
          .where(
            (exercise) => _passesFilter(
              exercise: exercise,
              slot: Slot(
                name: slot.name,
                acceptedBodyRegions: slot.acceptedBodyRegions,
                difficultyRange: slot.difficultyRange,
              ),
              template: request.template,
              activePainAreas: request.activePainAreas,
            ),
          )
          .toList(growable: false);
    }

    if (pool.isEmpty) {
      pool = request.catalog
          .where(
            (exercise) => _passesMinimumSafety(
              exercise: exercise,
              template: request.template,
              activePainAreas: request.activePainAreas,
            ),
          )
          .toList(growable: false);
    }

    final scored = pool
        .map(
          (exercise) => ScoredCandidate(
            exercise: exercise,
            score: scoring.score(
              exercise: exercise,
              fitnessLevel: request.fitnessLevel,
              goalKey: request.goalKey,
              activePainAreas: request.activePainAreas,
              recentExerciseIds: request.recentExerciseIds,
            ),
          ),
        )
        .toList();

    scored.sort((a, b) {
      final aAdjusted = _diversityAdjustedScore(a, selected);
      final bAdjusted = _diversityAdjustedScore(b, selected);
      return bAdjusted.compareTo(aAdjusted);
    });

    return scored;
  }

  bool _passesFilter({
    required ExerciseCatalogEntry exercise,
    required Slot slot,
    required Template template,
    required List<String> activePainAreas,
  }) {
    if (!_passesMinimumSafety(
      exercise: exercise,
      template: template,
      activePainAreas: activePainAreas,
    )) {
      return false;
    }

    final bodyMatches = exercise.bodyRegions.any(
      slot.acceptedBodyRegions.contains,
    );
    if (!bodyMatches) return false;

    final muscles = slot.acceptedMuscleGroups;
    if (muscles != null &&
        !exercise.muscleGroups.any((muscle) => muscles.contains(muscle))) {
      return false;
    }

    return exercise.difficultyTier >= slot.difficultyRange.min &&
        exercise.difficultyTier <= slot.difficultyRange.max;
  }

  bool _passesMinimumSafety({
    required ExerciseCatalogEntry exercise,
    required Template template,
    required List<String> activePainAreas,
  }) {
    final forkMatches =
        exercise.fork == template.fork || exercise.fork == 'both';
    if (!forkMatches || !exercise.isFormChecked || exercise.isCorrective) {
      return false;
    }

    return !exercise.painContraindicated.any(activePainAreas.contains);
  }

  ExerciseCatalogEntry _applyUnlockedVariant({
    required ExerciseCatalogEntry picked,
    required RecommendationRequest request,
    required Map<String, ExerciseCatalogEntry> catalogById,
  }) {
    final variantId = request.unlockedVariantByExerciseId[picked.id];
    if (variantId == null) return picked;

    final variant = catalogById[variantId];
    if (variant == null) return picked;
    if (!_passesMinimumSafety(
      exercise: variant,
      template: request.template,
      activePainAreas: request.activePainAreas,
    )) {
      return picked;
    }

    return variant;
  }

  double _diversityAdjustedScore(
    ScoredCandidate candidate,
    List<ExerciseCatalogEntry> selected,
  ) {
    if (selected.isEmpty) return candidate.score;

    final maxSimilarity = selected
        .map((exercise) =>
            _jaccard(candidate.exercise.muscleGroups, exercise.muscleGroups))
        .fold<double>(0, math.max);

    return (0.82 * candidate.score) - (0.18 * maxSimilarity);
  }

  double _jaccard(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 0;
    final aSet = a.toSet();
    final bSet = b.toSet();
    final intersection = aSet.intersection(bSet).length;
    final union = aSet.union(bSet).length;
    if (union == 0) return 0;
    return intersection / union;
  }
}
