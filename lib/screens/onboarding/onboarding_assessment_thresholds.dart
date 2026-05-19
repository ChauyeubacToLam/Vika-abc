import '../../services/recommendation/fitness_test_scoring.dart';

class OnboardingAssessmentThresholds {
  const OnboardingAssessmentThresholds._();

  static const double baseFormScore = 52;
  static const double repRatioWeight = 34;
  static const double heelFailPenalty = 3.0;
  static const double depthFailPenalty = 2.5;
  static const double trunkFailPenalty = 2.0;
  static const double tempoFailPenalty = 1.5;
  static const double syncFailPenalty = 1.5;
  static const double minFormScore = 38;
  static const double maxFormScore = 92;

  static const double goodDepthMaxAngle = 95;
  static const double okayDepthMaxAngle = 110;

  static const double beginnerDepthMaxAngle = 100;
  static const double intermediateDepthMaxAngle = 70;

  static const double beginnerCompMaxRatio = 0.4;
  static const double intermediateCompMaxRatio = 0.8;

  static const double depthWeight = 0.40;
  static const double compensationWeight = 0.35;
  static const double historyWeight = 0.25;

  static const double cvErraticThreshold = 20;
  static const double advancedLevelMin = 2.3;
  static const double intermediateLevelMin = 1.7;

  static const int strongScoreMin = 82;
  static const int decentScoreMin = 64;

  static int trainingDurationScore(String? trainingDuration) {
    return FitnessTestScorer.trainingDurationScore(trainingDuration);
  }

  static int computeFormScore({
    required double repRatio,
    required int heelFails,
    required int depthFails,
    required int trunkFails,
    required int tempoFails,
    required int syncFails,
  }) {
    final rawScore = baseFormScore +
        (repRatio * repRatioWeight) -
        (heelFails * heelFailPenalty) -
        (depthFails * depthFailPenalty) -
        (trunkFails * trunkFailPenalty) -
        (tempoFails * tempoFailPenalty) -
        (syncFails * syncFailPenalty);
    return rawScore.clamp(minFormScore, maxFormScore).round();
  }

  static String computeLevel({
    required double? avgDepth,
    required double goodRatio,
    required String? trainingDuration,
    required double kneeAngleCv,
  }) {
    return FitnessTestScorer.scoreHomeFiveRepAssessment(
      avgDepth: avgDepth,
      goodRatio: goodRatio,
      trainingDuration: trainingDuration,
      kneeAngleCv: kneeAngleCv,
    );
  }

  static String scoreCaption(int score) {
    if (score >= strongScoreMin) {
      return 'form ổn định, sẵn sàng tăng thử thách';
    }
    if (score >= decentScoreMin) {
      return 'nền tảng khá, còn vài điểm cần chỉnh';
    }
    return 'cần ưu tiên học form trước khi tăng cường độ';
  }

  static String depthCaption(double? avgDepth) {
    if (avgDepth == null) return 'Chưa đủ dữ liệu';
    if (avgDepth <= goodDepthMaxAngle) return 'Độ sâu tốt';
    if (avgDepth <= okayDepthMaxAngle) return 'Độ sâu ổn';
    return 'Độ sâu còn hạn chế';
  }
}
