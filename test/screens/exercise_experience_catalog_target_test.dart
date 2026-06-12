import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/12.Dead Bug/dead_bug.dart';
import 'package:vika/exercise/14.Bear Plank/bear_plank.dart';
import 'package:vika/exercise/3.High Plank/high_plank.dart';
import 'package:vika/exercise/4.Mountain Climber/mountain_climber.dart';
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
}
