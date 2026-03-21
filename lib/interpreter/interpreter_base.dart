import 'package:vinafit_mobile/utils/exercise_logger.dart';
import 'package:vinafit_mobile/interpreter/intepreting_map.dart';

class InterpreterConfig {
  static const double heelRise = 0.6;
}

class DetectedEvidence {
  final String issueId; // "ankle_mobility", "core_stability", etc.
  final double confidence; // 0.0 - 1.0
  final String exerciseSource; // "squat", "lunge"
  final String rawSignal; // "heel_rise_3_of_5"

  DetectedEvidence({
    required this.issueId,
    required this.confidence,
    required this.exerciseSource,
    required this.rawSignal,
  });
}

abstract class InterpreterBase {
  final ExerciseLogger logger;
  final String exerciseSource;
  final List<List<String>> questions = [];
  final List<String> detectedIssues = [];

  InterpreterBase({required this.logger, required this.exerciseSource});

  void addQuestion(int priority, String question) {
    while (questions.length <= priority) {
      questions.add([]);
    }
    questions[priority].add(question);
  }

  DetectedEvidence? interpretHeelRise(
      int heelCount, int maxRep, double maxHeelRise) {
    if (heelCount / maxRep > InterpreterConfig.heelRise) {
      addQuestion(interpretingMap["heel_rise"]!.priority,
          interpretingMap["heel_rise"]!.questions[0]);
      detectedIssues.add("ankle_mobility");
      return DetectedEvidence(
        issueId: "ankle_mobility",
        confidence: 1,
        exerciseSource: exerciseSource,
        rawSignal: "heel_rise_$heelCount/$maxRep",
      );
    }
    return null;
  }
}
