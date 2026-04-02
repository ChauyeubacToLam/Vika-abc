import 'package:vinafit_mobile/utils/exercise_logger.dart';
import 'package:vinafit_mobile/interpreter/intepreting_map.dart';

class InterpreterConfig {
  static const double heelRiseRatio = 0.6;
  static const double shallowDepthThreshold = 110.0;
  static const double trunkHeelRatio = 0.6;
  static const double forwardLean = 0.6;
}

class DetectedEvidence {
  final String issueId;
  final double confidence;
  final String exerciseSource;
  final String rawSignal;
  final String question;

  DetectedEvidence({
    required this.issueId,
    required this.confidence,
    required this.exerciseSource,
    required this.rawSignal,
    required this.question,
  });
}

abstract class InterpreterBase {
  String? id;
  final ExerciseLogger logger;
  final String exerciseSource;
  final List<List<DetectedEvidence>> evidences = [];
  final List<String> detectedIssues = [];
  final Map<String, double> _regionConfidence = {}; // bodyRegion → confidence

  InterpreterBase({required this.logger, required this.exerciseSource});

  void addEvidence(int priority, DetectedEvidence evidence) {
    while (evidences.length <= priority) {
      evidences.add([]);
    }
    evidences[priority].add(evidence);
  }

  DetectedEvidence? interprete(double confidence, String signal) {
    final issue = interpretingMap[id!]!;
    final region = issue.bodyRegion;

    // Dedup check
    if (_regionConfidence.containsKey(region) &&
        confidence <= _regionConfidence[region]!) {
      return null;
    }

    // If same region exists with lower confidence, replace it
    if (_regionConfidence.containsKey(region)) {
      detectedIssues.remove(detectedIssues
          .firstWhere((i) => interpretingMap[i]?.bodyRegion == region));
    }

    DetectedEvidence evidence = DetectedEvidence(
      issueId: id!,
      confidence: confidence,
      exerciseSource: exerciseSource,
      rawSignal: signal,
      question: issue.questions[0],
    );

    addEvidence(issue.priority, evidence);

    _regionConfidence[region] = confidence;
    detectedIssues.add(id!);
    return evidence;
  }

  DetectedEvidence? topEvidence() {
    for (final bucket in evidences) {
      if (bucket.isEmpty) continue;
      final sorted = [...bucket]
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      return sorted.first;
    }
    return null;
  }

  int countRepsWithAllFaultTypes(List<RepLog> repLogs, List<String> types) {
    return repLogs.where((rep) {
      final faults = (rep.data['fault_types'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toSet();
      return types.every(faults.contains);
    }).length;
  }

  DetectedEvidence? interpretHeelRise(int heelCount, int maxRep) {
    if (maxRep <= 0) return null;
    if (heelCount / maxRep >= InterpreterConfig.heelRiseRatio) {
      id = "ankle_mobility";
      return interprete(heelCount / maxRep, "heel_rise_$heelCount/$maxRep");
    }
    return null;
  }

  DetectedEvidence? interpretForwardLean(int forwardLeanCount, int maxRep) {
    final forwardLeanRatio = maxRep <= 0 ? 0.0 : forwardLeanCount / maxRep;
    if (forwardLeanRatio >= InterpreterConfig.forwardLean) {
      id = "hip_flexor_overactivity";
      return interprete(
          forwardLeanRatio, "forward_lean_$forwardLeanCount/$maxRep");
    }
    return null;
  }

  DetectedEvidence? interpretForwardLeanWithHeelRise(
      List<RepLog> repLogs, int maxRep, int forwardLeanCount) {
    final forwardLeanRatio = maxRep <= 0 ? 0.0 : forwardLeanCount / maxRep;
    if (forwardLeanRatio >= InterpreterConfig.forwardLean) {
      final trunkHeelCount =
          countRepsWithAllFaultTypes(repLogs, const ['Back', 'Feet']);
      double trunkHeelRatio = maxRep <= 0 ? 0.0 : trunkHeelCount / maxRep;
      if (trunkHeelRatio >= InterpreterConfig.trunkHeelRatio) {
        id = "ankle_mobility_restriction";
        return interprete(
          trunkHeelRatio * 2,
          "trunk_heel_${trunkHeelRatio.toStringAsFixed(2)}",
        );
      } else {
        id = "hip_flexor_overactivity";
        return interprete(
            forwardLeanRatio, "forward_lean_$forwardLeanCount/$maxRep");
      }
    }
    return null;
  }

  DetectedEvidence? interpretShallowDepth(double avgPeakDepth) {
    if (avgPeakDepth > InterpreterConfig.shallowDepthThreshold) {
      id = "limited_mobility";
      return interprete(
        (avgPeakDepth - InterpreterConfig.shallowDepthThreshold) /
            InterpreterConfig.shallowDepthThreshold,
        "shallow_depth_${avgPeakDepth.toStringAsFixed(1)}",
      );
    }
    return null;
  }
}
