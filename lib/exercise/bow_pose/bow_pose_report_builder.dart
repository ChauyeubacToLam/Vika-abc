import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class BowPoseReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': [
          'lift_form_seconds',
        ],
        'back': ['lift_form_seconds'],
        'shoulder_neck': ['connection_seconds'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'connection_seconds': (
          watch:
              'Trong Bow Pose: kết nối tay và chân có lúc chưa chắc nên tư thế bị kéo lệch.',
          next:
              'Giữ cổ chân như một tay nắm chắc, kéo thảm về hai phía thật đều.',
        ),
        'lift_form_seconds': (
          watch: 'Trong Bow Pose: ngực và đùi chưa nâng lên cùng nhịp an toàn.',
          next:
              'Nâng ngực và đùi như một khối, mắt nhìn xuống mép trước của thảm.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'connection_seconds': 'Kết nối tay-chân',
        'lift_form_seconds': 'Độ nâng',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Kết nối tay-chân': (c, t) =>
            'Kết nối tay-chân chắc $c/$t giây - rất tốt.',
        'Độ nâng': (c, t) => 'Độ nâng kiểm soát $c/$t giây - đẹp.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
