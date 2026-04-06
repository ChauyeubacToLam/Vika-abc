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
    final depthScore = _depthScore(avgDepth ?? 130);
    final compScore = _compensationScore(goodRatio);

    final histScore = trainingDurationScore(trainingDuration).clamp(1, 3);

    var weighted = (depthWeight * depthScore) +
        (compensationWeight * compScore) +
        (historyWeight * histScore);

    if (compScore <= 1.0) {
      // < 40% clean reps — cap at beginner regardless of depth
      weighted = weighted.clamp(0.0, intermediateLevelMin - 0.01);
    }
    if (kneeAngleCv > 0 && kneeAngleCv > cvErraticThreshold) {
      weighted = weighted.clamp(0.0, advancedLevelMin);
    }

    if (weighted > advancedLevelMin) return 'advanced';
    if (weighted >= intermediateLevelMin) return 'intermediate';
    return 'beginner';
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

  static double _depthScore(double avgAngle) {
    if (avgAngle > beginnerDepthMaxAngle) return 1.0;
    if (avgAngle > intermediateDepthMaxAngle) return 2.0;
    return 3.0;
  }

  static double _compensationScore(double goodRatio) {
    if (goodRatio < beginnerCompMaxRatio) return 1.0;
    if (goodRatio < intermediateCompMaxRatio) return 2.0;
    return 3.0;
  }
}
