import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class PrayerPoseReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'back': ['posture_stack_fails_count'],
        'lower_back': ['posture_stack_fails_count'],
        'shoulder_neck': ['posture_stack_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'posture_stack_fails_count': (
          watch:
              'Trong Prayer Pose: trục tai, vai và hông có lúc chưa chồng thẳng.',
          next: 'Đứng như lưng tựa vào tường, thả vai xuống và để ngực mở nhẹ.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'posture_stack_fails_count': 'Trục đứng',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Trục đứng': (c, t) => 'Trục đứng gọn $c/$t lượt giữ - nhẹ và chắc.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
