import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class JumpingJackReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'shoulder_neck': ['arm_fails_count'],
        'hip': ['leg_fails_count'],
        'knee': ['leg_fails_count'],
        'ankle': ['leg_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'arm_fails_count': (
          watch: 'Trong Jumping Jack: tay có lúc chưa mở đủ biên độ.',
          next: 'Vẽ một vòng cung lớn bằng hai bàn tay và chạm đường trên đầu.',
        ),
        'leg_fails_count': (
          watch:
              'Trong Jumping Jack: chân có lúc mở chưa đủ rộng hoặc lệch nhịp.',
          next:
              'Đáp hai bàn chân vào hai vạch song song rộng hơn hông rồi khép lại.',
        ),
        'tempo_fails_count': (
          watch: 'Trong Jumping Jack: nhịp mở-đóng còn chưa đều.',
          next:
              'Bám một nhịp đếm ổn định, mỗi lần mở và khép như một tiếng gõ.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'arm_fails_count': 'Tay mở',
        'leg_fails_count': 'Chân mở',
        'tempo_fails_count': 'Nhịp',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Tay mở': (c, t) => 'Tay mở đủ $c/$t rep - năng lượng tốt.',
        'Chân mở': (c, t) => 'Chân mở gọn $c/$t rep - rất ổn.',
        'Nhịp': (c, t) => 'Nhịp đều $c/$t rep - giữ tempo tốt.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
