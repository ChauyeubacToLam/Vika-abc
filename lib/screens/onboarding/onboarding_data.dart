import 'package:vika/interpreter/squat_interpreter.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/screens/onboarding/v5/fork_recommendation.dart';
import 'onboarding_assessment_thresholds.dart';

class OnboardingData {
  // Step 1: Why
  String? why; // Legacy alias retained for older unused onboarding pages.
  String? whyStep1; // 'body', 'pain', 'energy', 'strength'
  String? whyStep2;
  String whyCustomText = '';

  // Phase 1 resonance. IDs are locked for downstream profile queries.
  List<String> problemResonance = [];

  // Step 4: Pain check
  List<String> painAreas = []; // shared pain_region ids + 'other'
  Map<String, int> painIntensities = {}; // region id -> 1..5
  bool noPain = false;
  String? painOtherText; // free text when 'other' selected (optional)

  // Step 2: Goal
  String? goal;

  // Step 3: Frequency
  String? duration; // '<3m', '3-11m', '1y+'

  String? get trainingDuration => duration;
  set trainingDuration(String? value) => duration = value;

  // Step 5: Fork
  String? fork; // 'yoga' | 'home'

  // Step 5-7: Assessment
  List<String> detectedIssues = [];
  ExerciseLogger? _squatLogger;
  ExerciseLogger? pushUpLogger;
  SquatInterpreter? _squatInterpreter;
  Map<String, List<String>> feedbackByExercise = {};

  ForkRecommendation? forkRec;
  bool get hasSquatAssessment =>
      _squatLogger != null && _squatInterpreter != null;

  // Non-null getters preserve analyzer compatibility for older unused pages.
  ExerciseLogger get squatLogger => _squatLogger!;
  SquatInterpreter get squatInterpreter => _squatInterpreter!;
  SquatInterpreter? get squatInterpreterOrNull => _squatInterpreter;

  void onSquatComplete(ExerciseLogger logger) {
    _squatLogger = logger;
    _squatInterpreter = SquatInterpreter(logger: logger);
    _squatInterpreter!.analyze();
    detectedIssues
      ..clear()
      ..addAll(_squatInterpreter!.detectedIssues);
  }

  String? level;
  String? get confirmedLevel => level;
  set confirmedLevel(String? value) => level = value;

  String? issueAnswer;
  bool medicalClear = false;

  String? displayName;
  String? email;
  double? heightCm;
  double? weightKg;
  List<int> workoutDays = [];
  String? preferredTime;
  List<String> scheduleSessions = [];
  int? age;
  String? gender;

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
