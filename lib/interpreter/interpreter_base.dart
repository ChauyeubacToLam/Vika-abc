import 'package:vinafit_mobile/utils/exercise_logger.dart';
import 'package:vinafit_mobile/interpreter/intepreting_map.dart';

class InterpreterConfig {
  static const double heelRiseRatio = 0.6;
  static const double shallowDepthThreshold = 110.0;
}

class DetectedEvidence {
  final String issueId;
  final double confidence;
  final String exerciseSource;
  final String rawSignal;

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

  DetectedEvidence? interpretHeelRise(int heelCount, int maxRep) {
    if (maxRep <= 0) return null;
    if (heelCount / maxRep >= InterpreterConfig.heelRiseRatio) {
      addQuestion(interpretingMap["heel_rise"]!.priority,
          interpretingMap["heel_rise"]!.questions[0]);
      detectedIssues.add("ankle_mobility");
      return DetectedEvidence(
        issueId: "ankle_mobility",
        confidence: heelCount / maxRep,
        exerciseSource: exerciseSource,
        rawSignal: "heel_rise_$heelCount/$maxRep",
      );
    }
    return null;
  }

  DetectedEvidence? interpretShallowDepth(double avgPeakDepth) {
    if (avgPeakDepth > InterpreterConfig.shallowDepthThreshold) {
      addQuestion(interpretingMap["shallow_depth"]!.priority,
          interpretingMap["shallow_depth"]!.questions[0]);
      detectedIssues.add("limited_mobility");
      return DetectedEvidence(
        issueId: "limited_mobility",
        confidence:
            (avgPeakDepth - InterpreterConfig.shallowDepthThreshold) / 30.0,
        exerciseSource: exerciseSource,
        rawSignal: "avg_depth_${avgPeakDepth.toStringAsFixed(0)}",
      );
    }
    return null;
  }
}
