import 'dart:math' as math;

import '../../utils/exercise_logger.dart';

/// Vika v1 fitness-test tier scoring.
///
/// This file intentionally preserves the existing onboarding scoring behavior:
/// home users are scored from the 5-rep squat assessment, while yoga users use
/// the current placeholder mobility/feedback formula. Future protocols
/// (60-second tests, normative tables, research-backed composite scores) should
/// replace the logic in this file only. Callers should keep depending on the
/// `FitnessTestScorer.score` interface.
class FitnessTestScorer {
  const FitnessTestScorer._();

  static FitnessTestScoringResult score(FitnessTestScoringInput input) {
    final suggestedLevel =
        input.fork == 'yoga' ? _scoreYoga(input) : _scoreHome(input);
    return FitnessTestScoringResult(suggestedLevel: suggestedLevel);
  }

  static String _scoreHome(FitnessTestScoringInput input) {
    final squat = input.squatAssessment;
    if (squat == null) return 'beginner';

    final totalReps = squat.totalReps;
    final goodRatio = totalReps == 0 ? 0.0 : squat.goodReps / totalReps;
    final depths = squat.peakKneeAngles;
    final avgDepth =
        depths.isEmpty ? null : depths.reduce((a, b) => a + b) / depths.length;
    final cv = _kneeAngleCv(depths);

    return scoreHomeFiveRepAssessment(
      avgDepth: avgDepth,
      goodRatio: goodRatio,
      trainingDuration: input.trainingDuration,
      kneeAngleCv: cv,
    );
  }

  static String _scoreYoga(FitnessTestScoringInput input) {
    final yoga = input.yogaAssessment;
    if (yoga == null || yoga.chartValues.isEmpty) return 'beginner';

    final avg = yoga.chartValues.reduce((a, b) => a + b) /
        math.max(yoga.chartValues.length, 1);
    final depthScore = math.min(avg / yoga.chartTarget, 1.2);
    final compScore =
        1 - (yoga.confirmedIssueCount / math.max(yoga.totalIssueCandidates, 1));
    final historyScore = input.trainingDuration == '1y+'
        ? 0.85
        : input.trainingDuration == '3-11m'
            ? 0.5
            : 0.2;
    final weighted = 0.40 * depthScore + 0.35 * compScore + 0.25 * historyScore;
    final cappedScore = compScore < 0.5 ? math.min(weighted, 0.49) : weighted;
    final isNewToTraining =
        input.trainingDuration == null || input.trainingDuration == '<3m';
    if (isNewToTraining) return 'beginner';
    if (cappedScore >= 0.75) return 'advanced';
    if (cappedScore >= 0.55) return 'intermediate';
    return 'beginner';
  }

  static String scoreHomeFiveRepAssessment({
    required double? avgDepth,
    required double goodRatio,
    required String? trainingDuration,
    required double kneeAngleCv,
  }) {
    final depthScore = _depthScore(avgDepth ?? 130);
    final compScore = _compensationScore(goodRatio);

    final histScore = trainingDurationScore(trainingDuration).clamp(1, 3);

    var weighted = (_depthWeight * depthScore) +
        (_compensationWeight * compScore) +
        (_historyWeight * histScore);

    if (compScore <= 1.0) {
      weighted = weighted.clamp(0.0, _intermediateLevelMin - 0.01);
    }
    if (kneeAngleCv > 0 && kneeAngleCv > _cvErraticThreshold) {
      weighted = weighted.clamp(0.0, _advancedLevelMin);
    }

    if (weighted > _advancedLevelMin) return 'advanced';
    if (weighted >= _intermediateLevelMin) return 'intermediate';
    return 'beginner';
  }

  static int trainingDurationScore(String? trainingDuration) {
    switch (trainingDuration) {
      case '1y+':
        return 3;
      case '3-11m':
        return 2;
      case '<3m':
        return 1;
      default:
        return 0;
    }
  }

  static double _kneeAngleCv(List<double> angles) {
    if (angles.length < 3) return -1;
    final mean = angles.reduce((a, b) => a + b) / angles.length;
    if (mean == 0) return -1;
    final variance =
        angles.map((a) => (a - mean) * (a - mean)).reduce((a, b) => a + b) /
            angles.length;
    return (math.sqrt(variance) / mean) * 100;
  }

  static double _depthScore(double avgAngle) {
    if (avgAngle > _beginnerDepthMaxAngle) return 1.0;
    if (avgAngle > _intermediateDepthMaxAngle) return 2.0;
    return 3.0;
  }

  static double _compensationScore(double goodRatio) {
    if (goodRatio < _beginnerCompMaxRatio) return 1.0;
    if (goodRatio < _intermediateCompMaxRatio) return 2.0;
    return 3.0;
  }
}

class FitnessTestScoringInput {
  const FitnessTestScoringInput({
    required this.fork,
    required this.trainingDuration,
    this.squatAssessment,
    this.yogaAssessment,
  });

  final String? fork;
  final String? trainingDuration;
  final FiveRepAssessment? squatAssessment;
  final YogaMobilityAssessment? yogaAssessment;

  Map<String, dynamic> toJson() => {
        'fork': fork,
        'training_duration': trainingDuration,
        if (squatAssessment != null)
          'squat_assessment': squatAssessment!.toJson(),
        if (yogaAssessment != null) 'yoga_assessment': yogaAssessment!.toJson(),
      };

  factory FitnessTestScoringInput.fromSquatLogger({
    required ExerciseLogger? logger,
    required String? trainingDuration,
    String? fork = 'home',
  }) {
    if (logger == null) {
      return FitnessTestScoringInput(
        fork: fork,
        trainingDuration: trainingDuration,
      );
    }

    return FitnessTestScoringInput(
      fork: fork,
      trainingDuration: trainingDuration,
      squatAssessment: FiveRepAssessment.fromLogger(logger),
    );
  }
}

class FitnessTestScoringResult {
  const FitnessTestScoringResult({required this.suggestedLevel});

  final String suggestedLevel;
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
      totalReps: logger.repLogs.length,
      goodReps: (logger.setLogs['good_rep_count'] as int?) ?? 0,
      peakKneeAngles: angles,
    );
  }
}

class YogaMobilityAssessment {
  const YogaMobilityAssessment({
    required this.chartValues,
    required this.chartTarget,
    required this.totalIssueCandidates,
    required this.confirmedIssueCount,
  });

  final List<int> chartValues;
  final int chartTarget;
  final int totalIssueCandidates;
  final int confirmedIssueCount;

  Map<String, dynamic> toJson() => {
        'chart_values': chartValues,
        'chart_target': chartTarget,
        'total_issue_candidates': totalIssueCandidates,
        'confirmed_issue_count': confirmedIssueCount,
      };
}

const double _beginnerDepthMaxAngle = 100;
const double _intermediateDepthMaxAngle = 70;

const double _beginnerCompMaxRatio = 0.4;
const double _intermediateCompMaxRatio = 0.8;

const double _depthWeight = 0.40;
const double _compensationWeight = 0.35;
const double _historyWeight = 0.25;

const double _cvErraticThreshold = 20;
const double _advancedLevelMin = 2.3;
const double _intermediateLevelMin = 1.7;
