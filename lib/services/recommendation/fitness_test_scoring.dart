import '../../utils/exercise_logger.dart';

/// Vika v1 fitness-test tier scoring.
///
/// This file intentionally keeps onboarding scoring centralized: both forks are
/// banded by training duration and can only be degraded by assessment quality.
/// Home users degrade on clean-rep ratios; yoga users degrade on the parallel
/// clean-hold-seconds ratios. Future protocols
/// (60-second tests, normative tables, research-backed composite scores) should
/// replace the logic in this file only. Callers should keep depending on the
/// `FitnessTestScorer.score` interface.
class FitnessTestScorer {
  const FitnessTestScorer._();

  static FitnessTestScoringResult score(FitnessTestScoringInput input) {
    return input.fork == 'yoga' ? _scoreYoga(input) : _scoreHome(input);
  }

  static FitnessTestScoringResult _scoreHome(FitnessTestScoringInput input) {
    final squat = input.squatAssessment;
    final wallPushUp = input.wallPushUpAssessment;
    return _evaluateHome(
      trainingDuration: input.trainingDuration,
      squatCleanRatio: squat?.cleanRatio,
      wallPushUpCleanRatio: wallPushUp?.cleanRatio,
      assessmentA: squat == null
          ? null
          : AssessmentScore(
              exercise: 'squat',
              cleanRatio: squat.cleanRatio,
              good: squat.goodReps.toDouble(),
              total: squat.totalReps.toDouble(),
            ),
      assessmentB: wallPushUp == null
          ? null
          : AssessmentScore(
              exercise: 'wall_pushup',
              cleanRatio: wallPushUp.cleanRatio,
              good: wallPushUp.goodReps.toDouble(),
              total: wallPushUp.totalReps.toDouble(),
            ),
    );
  }

  static FitnessTestScoringResult _scoreYoga(FitnessTestScoringInput input) {
    final warrior = input.warriorAssessment;
    final forwardFold = input.forwardFoldAssessment;
    return _evaluateYoga(
      trainingDuration: input.trainingDuration,
      warriorCleanRatio: warrior?.cleanRatio,
      forwardFoldCleanRatio: forwardFold?.cleanRatio,
      assessmentA: warrior == null
          ? null
          : AssessmentScore(
              exercise: 'warrior_one',
              cleanRatio: warrior.cleanRatio,
              good: warrior.goodSeconds,
              total: warrior.totalSeconds,
            ),
      assessmentB: forwardFold == null
          ? null
          : AssessmentScore(
              exercise: 'seated_forward_fold',
              cleanRatio: forwardFold.cleanRatio,
              good: forwardFold.goodSeconds,
              total: forwardFold.totalSeconds,
            ),
    );
  }

  /// Thin string wrapper over [_evaluateHome] — preserved for callers that
  /// only need the level. The band + degrade logic lives in [_evaluateHome].
  static String scoreHomeFiveRepAssessment({
    required String? trainingDuration,
    double? squatCleanRatio,
    double? wallPushUpCleanRatio,
  }) =>
      _evaluateHome(
        trainingDuration: trainingDuration,
        squatCleanRatio: squatCleanRatio,
        wallPushUpCleanRatio: wallPushUpCleanRatio,
      ).suggestedLevel;

  /// Thin string wrapper over [_evaluateYoga] — preserved for callers that
  /// only need the level. The band + degrade logic lives in [_evaluateYoga].
  static String scoreYogaHoldAssessment({
    required String? trainingDuration,
    double? warriorCleanRatio,
    double? forwardFoldCleanRatio,
  }) =>
      _evaluateYoga(
        trainingDuration: trainingDuration,
        warriorCleanRatio: warriorCleanRatio,
        forwardFoldCleanRatio: forwardFoldCleanRatio,
      ).suggestedLevel;

  static FitnessTestScoringResult _evaluateHome({
    required String? trainingDuration,
    double? squatCleanRatio,
    double? wallPushUpCleanRatio,
    AssessmentScore? assessmentA,
    AssessmentScore? assessmentB,
  }) {
    final durationBand = _homeBandFromDuration(trainingDuration);
    final cleanRatios = [
      if (squatCleanRatio != null) _clampedRatio(squatCleanRatio),
      if (wallPushUpCleanRatio != null) _clampedRatio(wallPushUpCleanRatio),
    ];

    if (cleanRatios.isEmpty) {
      return FitnessTestScoringResult(
        suggestedLevel: durationBand,
        durationBand: durationBand,
        degraded: false,
        degradeThreshold: _homeCleanDegradeThreshold,
        assessmentA: assessmentA,
        assessmentB: assessmentB,
      );
    }

    final averageCleanRatio =
        cleanRatios.reduce((a, b) => a + b) / cleanRatios.length;
    final degraded = averageCleanRatio < _homeCleanDegradeThreshold;
    return FitnessTestScoringResult(
      suggestedLevel: degraded ? _degradeHomeBand(durationBand) : durationBand,
      durationBand: durationBand,
      degraded: degraded,
      degradeThreshold: _homeCleanDegradeThreshold,
      assessmentA: assessmentA,
      assessmentB: assessmentB,
    );
  }

  /// Yoga mirror of [_evaluateHome]: the same duration band and degrade-only
  /// model, but reads clean-hold-seconds ratios (good_seconds / total_seconds)
  /// instead of clean-rep ratios. Reuses the fork-agnostic band helpers; only
  /// the degrade threshold differs ([_yogaCleanDegradeThreshold]), because
  /// hold-% and rep-% scale differently.
  static FitnessTestScoringResult _evaluateYoga({
    required String? trainingDuration,
    double? warriorCleanRatio,
    double? forwardFoldCleanRatio,
    AssessmentScore? assessmentA,
    AssessmentScore? assessmentB,
  }) {
    final durationBand = _homeBandFromDuration(trainingDuration);
    final cleanRatios = [
      if (warriorCleanRatio != null) _clampedRatio(warriorCleanRatio),
      if (forwardFoldCleanRatio != null) _clampedRatio(forwardFoldCleanRatio),
    ];

    if (cleanRatios.isEmpty) {
      return FitnessTestScoringResult(
        suggestedLevel: durationBand,
        durationBand: durationBand,
        degraded: false,
        degradeThreshold: _yogaCleanDegradeThreshold,
        assessmentA: assessmentA,
        assessmentB: assessmentB,
      );
    }

    final averageCleanRatio =
        cleanRatios.reduce((a, b) => a + b) / cleanRatios.length;
    final degraded = averageCleanRatio < _yogaCleanDegradeThreshold;
    return FitnessTestScoringResult(
      suggestedLevel: degraded ? _degradeHomeBand(durationBand) : durationBand,
      durationBand: durationBand,
      degraded: degraded,
      degradeThreshold: _yogaCleanDegradeThreshold,
      assessmentA: assessmentA,
      assessmentB: assessmentB,
    );
  }

  static int trainingDurationScore(String? trainingDuration) {
    switch (trainingDuration) {
      case '2y+':
        return 3;
      case '6m-2y':
        return 2;
      case '<6m':
        return 1;
      default:
        return 0;
    }
  }

  static String _homeBandFromDuration(String? trainingDuration) {
    switch (trainingDuration) {
      case '2y+':
        return 'advanced';
      case '6m-2y':
        return 'intermediate';
      case '<6m':
      default:
        return 'beginner';
    }
  }

  static String _degradeHomeBand(String durationBand) {
    switch (durationBand) {
      case 'advanced':
        return 'intermediate';
      case 'intermediate':
        return 'beginner';
      case 'beginner':
      default:
        return 'beginner';
    }
  }

  static double _clampedRatio(double ratio) => ratio.clamp(0.0, 1.0).toDouble();
}

class FitnessTestScoringInput {
  const FitnessTestScoringInput({
    required this.fork,
    required this.trainingDuration,
    this.squatAssessment,
    this.wallPushUpAssessment,
    this.warriorAssessment,
    this.forwardFoldAssessment,
  });

  final String? fork;
  final String? trainingDuration;
  final FiveRepAssessment? squatAssessment;
  final FiveRepAssessment? wallPushUpAssessment;
  final YogaHoldAssessment? warriorAssessment;
  final YogaHoldAssessment? forwardFoldAssessment;

  Map<String, dynamic> toJson() => {
        'fork': fork,
        'training_duration': trainingDuration,
        if (squatAssessment != null)
          'squat_assessment': squatAssessment!.toJson(),
        if (wallPushUpAssessment != null)
          'wall_push_up_assessment': wallPushUpAssessment!.toJson(),
        if (warriorAssessment != null)
          'warrior_assessment': warriorAssessment!.toJson(),
        if (forwardFoldAssessment != null)
          'forward_fold_assessment': forwardFoldAssessment!.toJson(),
      };

  factory FitnessTestScoringInput.fromSquatLogger({
    required ExerciseLogger? logger,
    ExerciseLogger? wallPushUpLogger,
    required String? trainingDuration,
    String? fork = 'home',
  }) {
    return FitnessTestScoringInput(
      fork: fork,
      trainingDuration: trainingDuration,
      squatAssessment:
          logger == null ? null : FiveRepAssessment.fromLogger(logger),
      wallPushUpAssessment: wallPushUpLogger == null
          ? null
          : FiveRepAssessment.fromLogger(wallPushUpLogger),
    );
  }

  /// Yoga mirror of [fromSquatLogger]: reads the second-based hold loggers
  /// (Warrior I + Seated Forward Fold) instead of the rep-based loggers.
  factory FitnessTestScoringInput.fromYogaLoggers({
    required ExerciseLogger? warriorLogger,
    ExerciseLogger? forwardFoldLogger,
    required String? trainingDuration,
    String? fork = 'yoga',
  }) {
    return FitnessTestScoringInput(
      fork: fork,
      trainingDuration: trainingDuration,
      warriorAssessment: warriorLogger == null
          ? null
          : YogaHoldAssessment.fromLogger(warriorLogger),
      forwardFoldAssessment: forwardFoldLogger == null
          ? null
          : YogaHoldAssessment.fromLogger(forwardFoldLogger),
    );
  }
}

class FitnessTestScoringResult {
  const FitnessTestScoringResult({
    required this.suggestedLevel,
    required this.durationBand,
    required this.degraded,
    this.degradeThreshold,
    this.assessmentA,
    this.assessmentB,
  });

  /// The final scored level (duration band, possibly degraded). The string
  /// wrappers return exactly this value.
  final String suggestedLevel;

  /// The level implied by training duration alone, before any degrade.
  final String durationBand;

  /// True when the average clean ratio fell below [degradeThreshold] — true
  /// even when the band was already 'beginner' (so the level is unchanged).
  final bool degraded;

  /// The avg-clean-ratio threshold used for this fork (0.40 home / 0.50 yoga).
  final double? degradeThreshold;

  final AssessmentScore? assessmentA;
  final AssessmentScore? assessmentB;
}

/// One assessment exercise's contribution to the score. For the home fork
/// `good`/`total` are reps; for the yoga fork they are seconds.
class AssessmentScore {
  const AssessmentScore({
    required this.exercise,
    this.cleanRatio,
    this.good,
    this.total,
  });

  final String exercise;
  final double? cleanRatio;
  final double? good;
  final double? total;
}

class FiveRepAssessment {
  const FiveRepAssessment({
    required this.totalReps,
    required this.goodReps,
    required this.peakKneeAngles,
  });

  final int totalReps;
  final int goodReps;
  final List<double> peakKneeAngles;

  double? get cleanRatio => totalReps <= 0 ? null : goodReps / totalReps;

  Map<String, dynamic> toJson() => {
        'total_reps': totalReps,
        'good_reps': goodReps,
        'peak_knee_angles': peakKneeAngles,
      };

  factory FiveRepAssessment.fromLogger(ExerciseLogger logger) {
    final angles = logger.repLogs
        .map((r) => r.data['peak_knee_angle'] as num?)
        .whereType<num>()
        .map((v) => v.toDouble())
        .toList();
    return FiveRepAssessment(
      totalReps: (logger.setLogs['completed_reps'] as num?)?.toInt() ??
          logger.repLogs.length,
      goodReps: (logger.setLogs['good_rep_count'] as num?)?.toInt() ??
          logger.repLogs.where((r) => r.correctForm).length,
      peakKneeAngles: angles,
    );
  }
}

/// Second-based hold assessment for the yoga fork (Warrior I / Seated Forward
/// Fold). The clean-hold-seconds ratio is the yoga analogue of the home
/// clean-rep ratio.
class YogaHoldAssessment {
  const YogaHoldAssessment({
    required this.totalSeconds,
    required this.goodSeconds,
  });

  final double totalSeconds;
  final double goodSeconds;

  /// Fraction of the hold spent with good form. Null when no hold time was
  /// recorded (total_seconds <= 0); clamped to [0, 1] otherwise.
  double? get cleanRatio => totalSeconds <= 0
      ? null
      : (goodSeconds / totalSeconds).clamp(0.0, 1.0).toDouble();

  Map<String, dynamic> toJson() => {
        'total_seconds': totalSeconds,
        'good_seconds': goodSeconds,
      };

  /// Reads `total_seconds` + `good_seconds` from the hold loggers' setLogs.
  /// Both warrior_one.dart and seated_forward_fold.dart write exactly these
  /// keys in `onSetComplete` (good_seconds = clean-hold seconds, clamped to the
  /// target by the exercise).
  factory YogaHoldAssessment.fromLogger(ExerciseLogger logger) {
    final total = (logger.setLogs['total_seconds'] as num?)?.toDouble() ?? 0.0;
    final good = (logger.setLogs['good_seconds'] as num?)?.toDouble() ?? 0.0;
    return YogaHoldAssessment(totalSeconds: total, goodSeconds: good);
  }
}

const double _homeCleanDegradeThreshold = 0.40;
const double _yogaCleanDegradeThreshold = 0.50;
