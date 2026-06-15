import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class LowLungeReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'knee': ['knee_travel_fails_count'],
        'ankle': ['knee_travel_fails_count'],
        'shoulder_neck': ['cervical_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'knee_travel_fails_count': (
          watch: 'Trong Low Lunge: gối trước có xu hướng trôi quá xa.',
          next:
              'Neo gót chân trước xuống sàn và để gối đứng ngay trên cổ chân.',
        ),
        'cervical_fails_count': (
          watch: 'Trong Low Lunge: cổ có xu hướng căng khi giữ tư thế.',
          next:
              'Nhìn vào một điểm yên trước thảm, kéo đỉnh đầu dài về phía trước.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'knee_travel_fails_count': 'Gối trước',
        'cervical_fails_count': 'Cổ dài',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Gối trước': (c, t) => 'Gối trước ổn định $c/$t lượt giữ - tốt.',
        'Cổ dài': (c, t) => 'Cổ dài và nhẹ $c/$t lượt giữ - rất ổn.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
