import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class RaisedArmsReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['lumbar_backbend_fails_count'],
        'back': ['lumbar_backbend_fails_count'],
        'shoulder_neck': [
          'cervical_fails_count',
          'arm_position_fails_count',
        ],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'lumbar_backbend_fails_count': (
          watch: 'Trong Raised Arms: lưng dưới có xu hướng ưỡn quá mức.',
          next:
              'Ấn bàn chân xuống sàn và kéo xương sườn về gần hông khi vươn tay.',
        ),
        'cervical_fails_count': (
          watch: 'Trong Raised Arms: cổ có xu hướng ngửa theo tay.',
          next: 'Nhìn thẳng vào một điểm trước mặt, để gáy dài trong lúc vươn.',
        ),
        'arm_position_fails_count': (
          watch: 'Trong Raised Arms: tay chưa giữ được đường vươn ổn định.',
          next: 'Vươn các đầu ngón tay lên trần, để vai mềm và xa tai.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'lumbar_backbend_fails_count': 'Lưng dưới',
        'cervical_fails_count': 'Cổ dài',
        'arm_position_fails_count': 'Tay vươn',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Lưng dưới': (c, t) => 'Lưng dưới ổn định $c/$t lượt giữ - tốt.',
        'Cổ dài': (c, t) => 'Cổ giữ dài $c/$t lượt giữ - rất ổn.',
        'Tay vươn': (c, t) => 'Tay vươn gọn $c/$t lượt giữ - đẹp.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
