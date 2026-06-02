import 'dart:math' as math;

import '../models/workout_session_report.dart';

class SessionSummary {
  const SessionSummary({
    required this.rawFormScore,
    required this.sessionFormScore,
    required this.streakBonus,
    required this.streakDays,
    required this.exercises,
  });

  final int rawFormScore;
  final int sessionFormScore;
  final int streakBonus;
  final int streakDays;
  final List<SessionExerciseSummary> exercises;
}

class SessionExerciseSummary {
  const SessionExerciseSummary({
    required this.name,
    required this.formScore,
    required this.totalSets,
    this.totalReps,
    this.goodReps,
    this.totalSeconds,
    this.goodSeconds,
  });

  final String name;
  final int formScore;
  final int totalSets;
  final int? totalReps;
  final int? goodReps;
  final double? totalSeconds;
  final double? goodSeconds;
}

class SessionSummaryBuilder {
  const SessionSummaryBuilder._();

  static SessionSummary build(
    List<ExerciseSessionReport> reports,
    int streakDays,
  ) {
    final exercises = reports.map(_exerciseSummary).toList(growable: false);
    final scoreInputs = reports.map(_scoreInput).toList(growable: false);
    final repInputs =
        scoreInputs.where((input) => input.modality == _ScoreModality.rep);
    final holdInputs =
        scoreInputs.where((input) => input.modality == _ScoreModality.hold);
    final hasRepWork = repInputs.isNotEmpty;
    final hasHoldWork = holdInputs.isNotEmpty;

    final int rawFormScore;
    final bool hasScoreableWork;

    if (hasRepWork && hasHoldWork) {
      // TODO(session-summary): replace this interim path with cross-modal
      // total-sets weighting once hold active_seconds capture lands.
      hasScoreableWork = true;
      rawFormScore = _equalWeightMean(scoreInputs);
    } else if (hasRepWork || hasHoldWork) {
      final inputs = hasRepWork ? repInputs : holdInputs;
      hasScoreableWork = true;
      rawFormScore = _weightedMean(inputs);
    } else {
      hasScoreableWork = false;
      rawFormScore = 0;
    }

    final normalizedStreakDays = math.max(streakDays, 0);
    final potentialBonus = math.min(normalizedStreakDays, 5);
    final sessionFormScore =
        hasScoreableWork ? _clampInt(rawFormScore + potentialBonus, 0, 105) : 0;

    return SessionSummary(
      rawFormScore: rawFormScore,
      sessionFormScore: sessionFormScore,
      streakBonus: sessionFormScore - rawFormScore,
      streakDays: normalizedStreakDays,
      exercises: exercises,
    );
  }

  static SessionExerciseSummary _exerciseSummary(ExerciseSessionReport report) {
    final formScore = _clampFormScore(report.formScore);
    final postExercise = report.report;
    if (postExercise.isSecondBased) {
      return SessionExerciseSummary(
        name: report.exerciseName,
        formScore: formScore,
        totalSets: postExercise.sets.length,
        totalSeconds: postExercise.totalSeconds,
        goodSeconds: postExercise.goodSeconds,
      );
    }

    return SessionExerciseSummary(
      name: report.exerciseName,
      formScore: formScore,
      totalSets: postExercise.sets.length,
      totalReps: report.totalReps,
      goodReps: report.goodReps,
    );
  }

  static _ScoreInput _scoreInput(ExerciseSessionReport report) {
    final formScore = _clampFormScore(report.formScore);
    if (report.report.isSecondBased) {
      final seconds = report.report.totalSeconds;
      return seconds != null && seconds > 0
          ? _ScoreInput(_ScoreModality.hold, formScore, seconds)
          : _ScoreInput.unscoreable(formScore);
    }

    final reps = report.totalReps;
    return reps != null && reps > 0
        ? _ScoreInput(_ScoreModality.rep, formScore, reps.toDouble())
        : _ScoreInput.unscoreable(formScore);
  }

  static int _weightedMean(Iterable<_ScoreInput> inputs) {
    var weightedScore = 0.0;
    var totalWeight = 0.0;
    for (final input in inputs) {
      weightedScore += input.formScore * input.weight;
      totalWeight += input.weight;
    }
    if (totalWeight <= 0) return 0;
    return _clampFormScore((weightedScore / totalWeight).round());
  }

  static int _equalWeightMean(Iterable<_ScoreInput> inputs) {
    var scoreSum = 0;
    var count = 0;
    for (final input in inputs) {
      if (!input.isScoreable) continue;
      scoreSum += input.formScore;
      count += 1;
    }
    if (count == 0) return 0;
    return _clampFormScore((scoreSum / count).round());
  }

  static int _clampFormScore(int value) => _clampInt(value, 0, 100);

  static int _clampInt(int value, int min, int max) =>
      math.min(math.max(value, min), max);
}

enum _ScoreModality { rep, hold, unscoreable }

class _ScoreInput {
  const _ScoreInput(this.modality, this.formScore, this.weight);

  const _ScoreInput.unscoreable(this.formScore)
      : modality = _ScoreModality.unscoreable,
        weight = 0;

  final _ScoreModality modality;
  final int formScore;
  final double weight;

  bool get isScoreable => modality != _ScoreModality.unscoreable;
}
