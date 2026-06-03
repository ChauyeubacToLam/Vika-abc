import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/models/exercise_definition.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/models/workout_session_report.dart';
import 'package:vika/services/session_summary_builder.dart';

void main() {
  test('rep-only score is weighted by reps, not exercise count', () {
    final summary = SessionSummaryBuilder.build([
      _report(name: 'Squat', formScore: 100, totalReps: 10),
      _report(name: 'Push Up', formScore: 50, totalReps: 30),
    ], 2);

    expect(summary.rawFormScore, 63);
    expect(summary.sessionFormScore, 65);
    expect(summary.streakBonus, 2);
  });

  test('hold-only score is weighted by seconds', () {
    final summary = SessionSummaryBuilder.build([
      _report(
        name: 'Plank',
        formScore: 80,
        totalSeconds: 10,
        isSecondBased: true,
      ),
      _report(
        name: 'Warrior One',
        formScore: 20,
        totalSeconds: 30,
        isSecondBased: true,
      ),
    ], 0);

    expect(summary.rawFormScore, 35);
    expect(summary.sessionFormScore, 35);
    expect(summary.streakBonus, 0);
  });

  test('mixed modality uses equal exercise weight during interim launch path',
      () {
    final summary = SessionSummaryBuilder.build([
      _report(name: 'Squat', formScore: 100, totalReps: 40),
      _report(
        name: 'Plank',
        formScore: 0,
        totalSeconds: 150,
        isSecondBased: true,
      ),
    ], 0);

    expect(summary.rawFormScore, 50);
    expect(summary.sessionFormScore, 50);
  });

  test('zero scoreable work suppresses streak bonus', () {
    final summary = SessionSummaryBuilder.build([
      _report(name: 'Squat', formScore: 80, totalReps: 0),
    ], 5);

    expect(summary.rawFormScore, 0);
    expect(summary.sessionFormScore, 0);
    expect(summary.streakBonus, 0);
  });

  test('streak bonus caps at 5 and final score caps at 105', () {
    final summary = SessionSummaryBuilder.build([
      _report(name: 'Squat', formScore: 100, totalReps: 10),
    ], 99);

    expect(summary.rawFormScore, 100);
    expect(summary.sessionFormScore, 105);
    expect(summary.streakBonus, 5);
  });

  test('form score inputs are clamped before aggregation', () {
    final summary = SessionSummaryBuilder.build([
      _report(name: 'High', formScore: 140, totalReps: 10),
      _report(name: 'Low', formScore: -20, totalReps: 10),
    ], 0);

    expect(summary.rawFormScore, 50);
    expect(summary.sessionFormScore, 50);
    expect(summary.exercises.map((e) => e.formScore), [100, 0]);
  });

  test('post-exercise totals expose only the active scoring unit', () {
    final reps = _report(
      name: 'Squat',
      formScore: 70,
      totalReps: 10,
      goodReps: 7,
    ).report;
    final hold = _report(
      name: 'Plank',
      formScore: 75,
      totalSeconds: 20,
      goodSeconds: 15,
      isSecondBased: true,
    ).report;
    final empty = _report(name: 'Empty', formScore: 0, totalReps: 0).report;

    expect(reps.totalReps, 10);
    expect(reps.totalGoodReps, 7);
    expect(reps.totalSeconds, isNull);
    expect(reps.goodSeconds, isNull);
    expect(reps.cleanRatio, 0.7);

    expect(hold.totalReps, isNull);
    expect(hold.totalGoodReps, isNull);
    expect(hold.totalSeconds, 20);
    expect(hold.goodSeconds, 15);
    expect(hold.cleanRatio, 0.75);

    expect(empty.cleanRatio, isNull);
  });
}

ExerciseSessionReport _report({
  required String name,
  required int formScore,
  int? totalReps,
  int? goodReps,
  double? totalSeconds,
  double? goodSeconds,
  bool isSecondBased = false,
}) {
  return ExerciseSessionReport(
    definition: _definition(name),
    exerciseKey: name.toLowerCase().replaceAll(' ', '_'),
    report: PostExerciseData(
      exerciseName: name,
      metValue: 1,
      sets: [
        SetReportData(
          setIndex: 0,
          score: formScore,
          totalReps: totalReps,
          goodReps: goodReps ?? totalReps,
          totalSeconds: totalSeconds,
          goodSeconds: goodSeconds ?? totalSeconds,
          repResults: List<bool>.filled(totalReps ?? 0, true),
        ),
      ],
      formScore: formScore,
      coachText: '',
      isSecondBased: isSecondBased,
    ),
    duration: Duration.zero,
    calories: 0,
  );
}

ExerciseDefinition _definition(String name) {
  return ExerciseDefinition(
    id: name.toLowerCase().replaceAll(' ', '_'),
    name: name,
    subtitle: '',
    description: '',
    icon: Icons.fitness_center,
    primaryColor: Colors.black,
    secondaryColor: Colors.white,
    difficulty: '',
    targetMuscles: const [],
    duration: '',
    cameraHint: '',
    framingHint: '',
    setupTips: const [],
    createExercise: () => throw UnimplementedError(),
    phaseColors: const {},
  );
}
