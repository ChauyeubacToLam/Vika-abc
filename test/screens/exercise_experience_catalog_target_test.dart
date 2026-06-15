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
    expect(spec.secondsPerUnit, 1);
    expect(spec.exercise, isA<HighPlank>());
    expect((spec.exercise as HighPlank).maxSeconds, 36);
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
    expect(spec.exercise, isA<BearPlank>());
    expect((spec.exercise as BearPlank).maxSeconds, 24);
  });

  test('hand-cased exercises prefer prescription, then catalog reps', () {
    final cases = <({
      String id,
      int literal,
      int catalog,
      int prescription,
      int Function(Object exercise) targetOf,
    })>[
      (
        id: 'squat',
        literal: 8,
        catalog: 10,
        prescription: 12,
        targetOf: (exercise) => (exercise as Squat).maxRep,
      ),
      (
        id: 'lunge',
        literal: 8,
        catalog: 10,
        prescription: 12,
        targetOf: (exercise) => (exercise as Lunge).maxRep,
      ),
      (
        id: 'push_up',
        literal: 6,
        catalog: 9,
        prescription: 11,
        targetOf: (exercise) => (exercise as PushUp).maxRep,
      ),
      (
        id: 'plank',
        literal: 3,
        catalog: 4,
        prescription: 5,
        targetOf: (exercise) => (exercise as Plank).maxRep,
      ),
      (
        id: 'jumping_jack',
        literal: 15,
        catalog: 18,
        prescription: 20,
        targetOf: (exercise) => (exercise as JumpingJack).maxRep,
      ),
      (
        id: 'warrior_one',
        literal: 2,
        catalog: 4,
        prescription: 6,
        targetOf: (exercise) => (exercise as WarriorOne).maxHolds,
      ),
      (
        id: 'glute_bridge',
        literal: 15,
        catalog: 18,
        prescription: 20,
        targetOf: (exercise) => (exercise as GluteBridge).maxRep,
      ),
      (
        id: 'curl_up',
        literal: 12,
        catalog: 14,
        prescription: 16,
        targetOf: (exercise) => (exercise as CurlUp).maxRep,
      ),
    ];

    for (final entry in cases) {
      final definition = lookupExerciseDefinition(entry.id)!;
      final info = catalogInfo(
        id: entry.id,
        baseReps: entry.catalog,
        baseSeconds: 99,
      );

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

      final literalBacked = debugBuildExerciseExperienceSpec(definition);
      expect(
        literalBacked.targetPerSet,
        entry.literal,
        reason: '${entry.id} should retain its literal fallback',
      );
      expect(entry.targetOf(literalBacked.exercise), entry.literal);
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
