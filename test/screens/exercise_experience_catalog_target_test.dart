import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/12.Dead Bug/dead_bug.dart';
import 'package:vika/exercise/14.Bear Plank/bear_plank.dart';
import 'package:vika/exercise/3.High Plank/high_plank.dart';
import 'package:vika/exercise/4.Mountain Climber/mountain_climber.dart';
import 'package:vika/exercise/curl_up/curl_up.dart';
import 'package:vika/exercise/glute bridge/glute_bridge.dart';
import 'package:vika/exercise/jumping jack/jumping_jack.dart';
import 'package:vika/exercise/lunge/lunge.dart';
import 'package:vika/exercise/plank/plank.dart';
import 'package:vika/exercise/push up/push_up.dart';
import 'package:vika/exercise/squat/squat.dart';
import 'package:vika/exercise/wall_push_up/wall_push_up.dart';
import 'package:vika/exercise/warrior_1/warrior_one.dart';
import 'package:vika/exercise/seated_forward_fold/seated_forward_fold.dart';
import 'package:vika/exercise/side_plank_dip/side_plank_dip.dart';
import 'package:vika/exercise/Sphinx_Pose/sphinx_stretch.dart';
import 'package:vika/models/exercise_definition.dart';
import 'package:vika/models/exercise_lookup.dart';
import 'package:vika/screens/exercise/exercise_experience_screen.dart';
import 'package:vika/services/recommendation/models/plan.dart';
import 'package:vika/services/recommendation/recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ExerciseLaunchCatalogInfo catalogInfo({
    required String id,
    int? baseReps,
    int? baseSeconds,
  }) {
    return ExerciseLaunchCatalogInfo(
      id: id,
      isFormChecked: true,
      baseReps: baseReps,
      baseSeconds: baseSeconds,
    );
  }

  test('planned default-branch rep exercise uses prescribed reps', () {
    final definition = lookupExerciseDefinition('dead__bug')!;

    final spec = debugBuildExerciseExperienceSpec(
      definition,
      prescription: const VolumePrescription(
        sets: 3,
        restSeconds: 60,
        reps: 14,
      ),
      catalogInfo: catalogInfo(id: 'dead__bug', baseReps: 8),
    );

    expect(spec.sets, 3);
    expect(spec.targetPerSet, 14);
    expect(spec.targetLabel, 'REP/HIỆP');
    expect(spec.exercise, isA<DeadBug>());
    expect((spec.exercise as DeadBug).maxRep, 14);
  });

  test('planned high plank uses prescribed seconds and hold presentation', () {
    final definition = lookupExerciseDefinition('high__plank')!;

    final spec = debugBuildExerciseExperienceSpec(
      definition,
      prescription: const VolumePrescription(
        sets: 2,
        restSeconds: 45,
        seconds: 36,
      ),
      catalogInfo: catalogInfo(id: 'high__plank', baseSeconds: 20),
    );

    expect(spec.sets, 2);
    expect(spec.targetPerSet, 36);
    expect(spec.targetLabel, 'GIÂY/HIỆP');
    expect(spec.hybrid, isTrue);
    expect(spec.repHeroTarget, 1);
    expect(spec.secondsPerUnit, 1);
    expect(spec.timeBased, isTrue);
    expect(spec.exercise, isA<HighPlank>());
    expect((spec.exercise as HighPlank).maxHolds, 1);
    expect((spec.exercise as HighPlank).holdSeconds, 36);
  });

  test('hybrid high plank catalog passes hold count and per-hold seconds', () {
    final definition = lookupExerciseDefinition('high__plank')!;

    final spec = debugBuildExerciseExperienceSpec(
      definition,
      catalogInfo: catalogInfo(
        id: 'high__plank',
        baseReps: 3,
        baseSeconds: 30,
      ),
    );

    final exercise = spec.exercise as HighPlank;
    expect(spec.targetPerSet, 30);
    expect(spec.targetLabel, 'GIÂY/HIỆP');
    expect(spec.timeBased, isTrue);
    expect(spec.hybrid, isTrue);
    expect(spec.repHeroTarget, 3);
    expect(exercise.maxHolds, 3);
    expect(exercise.holdSeconds, 30);
  });

  test('catalog base reps are the fallback when prescription is absent', () {
    final definition = lookupExerciseDefinition('mountain__climber')!;

    final spec = debugBuildExerciseExperienceSpec(
      definition,
      catalogInfo: catalogInfo(id: 'mountain__climber', baseReps: 18),
    );

    expect(spec.targetPerSet, 18);
    expect(spec.targetLabel, 'REP/HIỆP');
    expect(spec.exercise, isA<MountainClimber>());
    expect((spec.exercise as MountainClimber).maxRep, 18);
  });

  test('catalog base seconds make bear plank a time hold', () {
    final definition = lookupExerciseDefinition('bear__plank')!;

    final spec = debugBuildExerciseExperienceSpec(
      definition,
      catalogInfo: catalogInfo(id: 'bear__plank', baseSeconds: 24),
    );

    expect(spec.targetPerSet, 24);
    expect(spec.targetLabel, 'GIÂY/HIỆP');
    expect(spec.secondsPerUnit, 1);
    expect(spec.timeBased, isTrue);
    expect(spec.exercise, isA<BearPlank>());
    expect((spec.exercise as BearPlank).maxSeconds, 24);
  });

  test('static stretch definitions launch and display as seconds', () {
    final cases = <({String id, int Function(Object) targetOf})>[
      (
        id: 'seated__forward__fold',
        targetOf: (exercise) => (exercise as SeatedForwardFold).maxSeconds,
      ),
      (
        id: 'side__plank_with__hip__dip',
        targetOf: (exercise) => (exercise as SidePlankDip).maxSeconds,
      ),
      (
        id: 'sphinx_',
        targetOf: (exercise) => (exercise as SphinxStretch).maxSeconds,
      ),
    ];

    for (final entry in cases) {
      final definition = lookupExerciseDefinition(entry.id)!;
      final spec = debugBuildExerciseExperienceSpec(
        definition,
        catalogInfo: catalogInfo(id: entry.id, baseSeconds: 15),
      );

      expect(spec.targetPerSet, 15, reason: entry.id);
      expect(spec.targetLabel, 'GIÂY/HIỆP', reason: entry.id);
      expect(spec.timeBased, isTrue, reason: entry.id);
      expect(entry.targetOf(spec.exercise), 15, reason: entry.id);
    }
  });

  test('hand-cased exercises prefer prescription, then catalog reps', () {
    final cases = <({
      String id,
      int catalog,
      int prescription,
      int Function(Object exercise) targetOf,
    })>[
      (
        id: 'squat',
        catalog: 10,
        prescription: 12,
        targetOf: (exercise) => (exercise as Squat).maxRep,
      ),
      (
        id: 'lunge',
        catalog: 10,
        prescription: 12,
        targetOf: (exercise) => (exercise as Lunge).maxRep,
      ),
      (
        id: 'push_up',
        catalog: 9,
        prescription: 11,
        targetOf: (exercise) => (exercise as PushUp).maxRep,
      ),
      (
        id: 'plank',
        catalog: 4,
        prescription: 5,
        targetOf: (exercise) => (exercise as Plank).maxRep,
      ),
      (
        id: 'jumping_jack',
        catalog: 18,
        prescription: 20,
        targetOf: (exercise) => (exercise as JumpingJack).maxRep,
      ),
      (
        id: 'warrior_one',
        catalog: 4,
        prescription: 6,
        targetOf: (exercise) => (exercise as WarriorOne).maxHolds,
      ),
      (
        id: 'glute_bridge',
        catalog: 18,
        prescription: 20,
        targetOf: (exercise) => (exercise as GluteBridge).maxRep,
      ),
      (
        id: 'curl_up',
        catalog: 14,
        prescription: 16,
        targetOf: (exercise) => (exercise as CurlUp).maxRep,
      ),
    ];

    for (final entry in cases) {
      final definition = lookupExerciseDefinition(entry.id)!;
      final info = catalogInfo(id: entry.id, baseReps: entry.catalog);

      final prescribed = debugBuildExerciseExperienceSpec(
        definition,
        prescription: VolumePrescription(
          sets: 3,
          restSeconds: 45,
          reps: entry.prescription,
        ),
        catalogInfo: info,
      );
      expect(
        prescribed.targetPerSet,
        entry.prescription,
        reason: '${entry.id} should prefer prescription reps',
      );
      expect(entry.targetOf(prescribed.exercise), entry.prescription);

      final catalogBacked = debugBuildExerciseExperienceSpec(
        definition,
        catalogInfo: info,
      );
      expect(
        catalogBacked.targetPerSet,
        entry.catalog,
        reason: '${entry.id} should fall back to catalog baseReps',
      );
      expect(entry.targetOf(catalogBacked.exercise), entry.catalog);

      // No catalog entry AND no prescription → never-crash floor. Volume now
      // lives only in the catalog, so there is no per-definition literal to
      // fall back to; every exercise floors to kFallbackReps.
      final floored = debugBuildExerciseExperienceSpec(definition);
      expect(
        floored.targetPerSet,
        kFallbackReps,
        reason: '${entry.id} floors to kFallbackReps with no catalog entry',
      );
      expect(entry.targetOf(floored.exercise), kFallbackReps);
    }
  });

  test('assessment exercises stay fixed at five reps', () {
    final squatSpec = debugBuildExerciseExperienceSpec(
      squatAssessmentDefinition,
      prescription: const VolumePrescription(
        sets: 2,
        reps: 12,
        restSeconds: 45,
      ),
      catalogInfo: catalogInfo(id: 'squat_assessment', baseReps: 99),
    );
    expect(squatSpec.targetPerSet, 5);
    expect((squatSpec.exercise as Squat).maxRep, 5);

    final wallPushupSpec = debugBuildExerciseExperienceSpec(
      wallPushupAssessmentDefinition,
      prescription: const VolumePrescription(
        sets: 2,
        reps: 12,
        restSeconds: 45,
      ),
      catalogInfo: catalogInfo(id: 'wall_pushup_assessment', baseReps: 99),
    );
    expect(wallPushupSpec.targetPerSet, 5);
    expect((wallPushupSpec.exercise as WallPushUp).maxRep, 5);
  });
}
