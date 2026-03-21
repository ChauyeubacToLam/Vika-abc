import 'package:vinafit_mobile/interpreter/interpreter_base.dart';

class SquatInterpreter extends InterpreterBase {
  SquatInterpreter({required super.logger}) : super(exerciseSource: "squat");

  void analyze() {
    interpretHeelRise(
        logger.setLogs["heel_fails_count"] ?? 0,
        logger.setLogs["max_rep"] ?? 0,
        logger.setLogs["max_heel_distance"] ?? 0);
  }

  String getQuestion() {
    for (var i = 0; i < questions.length; i++) {
      if (questions[i].isNotEmpty) {
        return questions[i][0];
      }
    }
    return "";
  }
}
