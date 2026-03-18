/// Stores all data collected during onboarding.
/// Passed through each step and saved at the end.
class OnboardingData {
  String? goal; // 'lose_weight', 'tone', 'health'
  String? timeCommitment; // '10', '20', '30'
  bool medicalOk = false;

  // Assessment results (filled after 5-squat test)
  int totalReps = 0;
  int goodReps = 0;
  double? avgDepthAngle; // average min knee angle across reps
  double? maxTrunkLean; // worst trunk lean seen
  int heelRiseCount = 0; // how many reps had heel rise
  double? avgDescentTime;
  double? avgAscentTime;

  // Post-signup body data
  double? heightCm;
  double? weightKg;

  // Account
  String? displayName;
  String? email;

  /// Derived fitness level from assessment
  String get fitnessLevel {
    if (avgDepthAngle == null) return 'beginner';
    final depth = avgDepthAngle!;
    final trunk = maxTrunkLean ?? 50;
    if (depth > 120 || trunk > 40) return 'beginner';
    if (depth > 100 || trunk > 30) return 'intermediate';
    return 'advanced';
  }

  /// Mobility assessment
  String get mobilityLevel {
    if (avgDepthAngle == null) return 'limited';
    if (avgDepthAngle! > 120) return 'limited';
    if (avgDepthAngle! > 100) return 'average';
    return 'good';
  }

  /// Core stability assessment
  String get stabilityLevel {
    if (maxTrunkLean == null) return 'weak';
    if (maxTrunkLean! > 40) return 'weak';
    if (maxTrunkLean! > 25) return 'average';
    return 'good';
  }

  /// Whether ankle mobility is flagged
  bool get hasAnkleIssue => heelRiseCount >= 3;
}
