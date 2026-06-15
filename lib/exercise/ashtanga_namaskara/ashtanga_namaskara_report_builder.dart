import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class AshtangaNamaskaraReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'hip': ['hip_collapse_fails_count'],
        'lower_back': ['hip_collapse_fails_count'],
        'shoulder_neck': ['cervical_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'hip_collapse_fails_count': (
          watch:
              'Trong Ashtanga Namaskara: hông có xu hướng rơi thấp khi hạ người.',
          next:
              'Giữ hông như được một sợi dây nâng lên, đặt lực đều qua tay, gối và ngực.',
        ),
        'cervical_fails_count': (
          watch:
              'Trong Ashtanga Namaskara: cổ có xu hướng ngước hoặc gập quá mức.',
          next: 'Nhìn xuống một điểm trên thảm trước mặt, để gáy dài và mềm.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'hip_collapse_fails_count': 'Hông vững',
        'cervical_fails_count': 'Cổ an toàn',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Hông vững': (c, t) => 'Hông giữ tốt $c/$t rep - rất chắc.',
        'Cổ an toàn': (c, t) => 'Cổ trung tính $c/$t rep - tốt lắm.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
