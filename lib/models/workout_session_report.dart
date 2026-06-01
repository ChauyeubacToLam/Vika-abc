// Accumulator carried forward through a multi-exercise workout sequence.
//
// Each [ExerciseSessionReport] captures the result of ONE finished exercise.
// As the sequence progresses, reports pile up in [ExerciseLaunchArgs.priorReports]
// and are eventually handed to [WorkoutSummaryScreen] to compute session-wide
// stats (total reps, total duration, session form score, aggregated coach AI,
// top issue across exercises).
//
// `userDifficulty` is filled in by the user on the *next* exercise's intro
// page, not on the exercise that produced the report. The last exercise's
// difficulty is filled in on the workout summary screen.

import '../models/exercise_definition.dart';
import '../models/post_exercise_data.dart';

class ExerciseSessionReport {
  ExerciseSessionReport({
    required this.definition,
    required this.report,
    required this.duration,
    required this.calories,
    this.sessionId,
    this.userDifficulty,
  });

  final ExerciseDefinition definition;
  final PostExerciseData report;
  final Duration duration;
  final int calories;
  final String? sessionId;

  /// 'light' / 'medium' / 'heavy' — collected on the NEXT intro (or on
  /// the workout summary for the last exercise).
  String? userDifficulty;

  int get totalReps => report.totalReps;
  int get goodReps => report.totalGoodReps;
  int get formScore => report.formScore;
  String get exerciseName => report.exerciseName;
}
