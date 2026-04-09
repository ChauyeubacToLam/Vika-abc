import 'package:vinafit_mobile/interpreter/squat_interpreter.dart';
import 'package:vinafit_mobile/utils/exercise_logger.dart';

import 'onboarding_assessment_thresholds.dart';

class OnboardingData {
  // Step 1: Why
  String? why; // 'pain', 'confidence', 'energy', 'health'
  List<String> painAreas =
      []; // 'none', 'lower_back', 'knee', 'shoulder_neck', 'hip', 'other'
  String? painOtherText; // free text when 'other' selected (optional)

  // Step 2: Goal
  String? goal;

  // Step 3: Frequency
  String? trainingDuration; // '<3m', '3-11m', '1y+'

  // Step 5-7: Assessment
  List<String> detectedIssues = [];
  late ExerciseLogger squatLogger;
  // ExerciseLogger? pushUpLogger;
  late SquatInterpreter squatInterpreter;

  void onSquatComplete(ExerciseLogger logger) {
    squatLogger = logger;
    squatInterpreter = SquatInterpreter(logger: logger);
    squatInterpreter.analyze();
    detectedIssues
      ..clear()
      ..addAll(squatInterpreter.detectedIssues);
  }

  String? confirmedLevel;
  String? issueAnswer;
  bool medicalClear = false;

  String? displayName;
  String? email;
  double? heightCm;
  double? weightKg;
  List<int> workoutDays = [];
  String? preferredTime;

  String? timeCommitment;
  String? program;

  int get frequencyScore {
    return OnboardingAssessmentThresholds.trainingDurationScore(
      trainingDuration,
    );
  }

  double? get bmi {
    if (heightCm == null || weightKg == null) return null;
    if (heightCm! <= 0) return null;
    return weightKg! / ((heightCm! / 100) * (heightCm! / 100));
  }

  String get bmiCategory {
    final b = bmi;
    if (b == null) return '';
    if (b < 18.5) return 'underweight';
    if (b < 23) return 'normal';
    if (b < 25) return 'overweight';
    return 'obese';
  }
}
