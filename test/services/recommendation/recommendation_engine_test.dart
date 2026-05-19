import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/recommendation/models/exercise_catalog_entry.dart';
import 'package:vika/services/recommendation/models/plan.dart';
import 'package:vika/services/recommendation/recommendation_engine.dart';
import 'package:vika/services/recommendation/templates.dart';

ExerciseCatalogEntry _exercise({
  required String id,
  required List<String> bodyRegions,
  required List<String> muscleGroups,
  int baseReps = 8,
}) {
  return ExerciseCatalogEntry(
    id: id,
    vietnameseName: id,
    englishName: id,
    fork: 'both',
    bodyRegions: bodyRegions,
    muscleGroups: muscleGroups,
    difficultyTier: 1,
    goalFit: const {
      'health': 0.9,
      'body': 0.8,
      'strength': 0.8,
      'flexible': 0.7,
    },
    painSafe: const [],
    painContraindicated: const [],
    isFormChecked: true,
    isCorrective: false,
    correctiveFor: const [],
    baseReps: baseReps,
    maxRepsBeginner: baseReps + 2,
    maxRepsIntermediate: baseReps + 4,
    maxRepsAdvanced: baseReps + 6,
  );
}

void main() {
  test('generates full v4.4 plan with deload, check-ins, and retest', () {
    final template = launchTemplates['home_health']!;
    final catalog = [
      _exercise(
        id: 'squat',
        bodyRegions: const ['lower_body'],
        muscleGroups: const ['quads', 'glutes'],
      ),
      _exercise(
        id: 'push_up',
        bodyRegions: const ['upper_body'],
        muscleGroups: const ['chest', 'shoulders'],
        baseReps: 6,
      ),
      _exercise(
        id: 'plank',
        bodyRegions: const ['core'],
        muscleGroups: const ['core'],
        baseReps: 3,
      ),
      _exercise(
        id: 'glute_bridge',
        bodyRegions: const ['lower_body'],
        muscleGroups: const ['glutes', 'hamstrings'],
      ),
    ];

    final result = const RecommendationEngine().generatePlan(
      RecommendationRequest(
        recommendationId: 'rec-1',
        userId: 'user-1',
        template: template,
        catalog: catalog,
        fitnessLevel: 'beginner',
        goalKey: 'health',
        activePainAreas: const [],
        recentExerciseIds: const [],
        rngSeed: 'seed',
        sessionsPerWeek: 3,
      ),
    );

    expect(result.algorithmVersion, kRecommendationAlgorithmVersion);
    expect(result.plan.weeks, hasLength(7));
    expect(result.plan.weeklyCheckInWeeks, [2, 3, 4, 5, 6, 7]);
    expect(result.plan.endOfPlanRetest, isNotNull);
    expect(result.plan.weeks.last.isDeloadWeek, isTrue);
    expect(result.plan.weeks.last.phaseName, 'Phục hồi');

    final weekOneExercises = result.plan.weeks.first.sessions.first.slots
        .map((slot) => slot.exerciseId)
        .toList();
    final weekSixExercises = result.plan.weeks[5].sessions.first.slots
        .map((slot) => slot.exerciseId)
        .toList();
    expect(weekSixExercises, weekOneExercises);

    final weekOneSquat = result.plan.weeks.first.sessions.first.slots.first;
    final weekSixSquat = result.plan.weeks[5].sessions.first.slots.first;
    expect(
      weekOneSquat.volume.reps!,
      lessThanOrEqualTo(weekSixSquat.volume.reps!),
    );
    expect(
        result.plan.weeks.last.sessions.first.slots.first.volume.isDeloadWeek,
        isTrue);
  });

  test('legacy plan JSON without slot volume still deserializes', () {
    final plan = Plan.fromSupabase(
      recommendationId: 'legacy-rec',
      userId: 'user-1',
      templateKey: 'home_health',
      planStructure: const {
        'weeks': [
          {
            'week_number': 1,
            'phase_name': 'Khởi đầu',
            'volume': {'sets': 3, 'reps': 8, 'rest_seconds': 60},
            'sessions': [
              {
                'session_index': 0,
                'slots': [
                  {
                    'slot_name': 'lower',
                    'exercise_id': 'squat',
                    'score': 0.9,
                  }
                ],
              }
            ],
          }
        ],
      },
    );

    expect(plan.schemaVersion, 'legacy');
    expect(plan.weeks.single.phaseNumber, 1);
    expect(plan.weeks.single.sessions.single.slots.single.volume.reps, 8);
  });
}
