import 'package:vinafit_mobile/interpreter/squat_interpreter.dart';
import 'package:vinafit_mobile/utils/exercise_logger.dart';

class OnboardingData {
  // ── Step 1: Goal ──
  String? goal;

  // ── Step 2: Experience ──
  String? experience; // 'never', 'sometimes', 'regularly'

  // ── Step 3: Medical ──
  bool medicalClear = false;

  // ── Step 4-5: Assessment ──
  List<String> detectedIssues = [];
  late ExerciseLogger squatLogger;
  // ExerciseLogger? pushUpLogger;
  late SquatInterpreter squatInterpreter;

  void onSquatComplete(ExerciseLogger logger) {
    squatLogger = logger;
    squatInterpreter = SquatInterpreter(logger: logger);
    squatInterpreter.analyze();
    detectedIssues.addAll(squatInterpreter.detectedIssues);
  }

  // void onPushUpComplete(ExerciseLogger logger) {
  //   // pushUpLogger = logger;
  // }

  // ── Step 7: Level ──
  String? confirmedLevel;

  // ── Step 8: Issue spotlight ──
  String? issueAnswer; // user's yes/no

  // ── Step 9-10: Signup + Body ──
  String? displayName;
  String? email;
  double? heightCm;
  double? weightKg;
  List<int> workoutDays = [];
  String? preferredTime;

  // ── Step 11: time commitment ──
  String? timeCommitment;

  // ── Step 12: Program ──
  String? program;

  // ── Derived ──
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
