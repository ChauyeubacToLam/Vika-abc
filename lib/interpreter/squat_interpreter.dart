import 'package:vinafit_mobile/interpreter/interpreter_base.dart';

class SquatInterpreter extends InterpreterBase {
  SquatInterpreter({required super.logger}) : super(exerciseSource: "squat");

  void analyze() {
    interpretHeelRise(
      logger.setLogs["heel_fails_count"] ?? 0,
      logger.setLogs["max_rep"] ?? 0,
    );

    interpretForwardLeanWithHeelRise(
      logger.repLogs,
      logger.setLogs["max_rep"] ?? 0,
      logger.setLogs["trunk_lean_fails_count"] ?? 0,
    );

    // Avg peak depth across reps
    final depths = logger.repLogs
        .map((r) => r.data["peak_knee_angle"] as num?)
        .whereType<num>()
        .toList();
    if (depths.isNotEmpty) {
      final avg = depths.reduce((a, b) => a + b) / depths.length;
      interpretShallowDepth(avg.toDouble());
    }
  }

  String? getQuestion() => topEvidence()?.question;
  String? getPrimaryIssueId() => topEvidence()?.issueId;

  String? getPrimaryIssueReason() => topEvidence()?.rawSignal;
}
