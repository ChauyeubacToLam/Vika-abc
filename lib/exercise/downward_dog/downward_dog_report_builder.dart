import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class DownwardDogReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'back': ['spine_round_seconds'],
        'lower_back': ['spine_round_seconds'],
        'shoulder_neck': ['shoulder_shrug_seconds'],
        'knee': ['leg_straightness_seconds'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'spine_round_seconds': (
          watch: 'Trong Chó Cúi Mặt: lưng có xu hướng bo tròn khi giữ tư thế.',
          next: 'Đẩy thảm ra xa và kéo hông lên cao như chạm trần, giữ cổ dài.',
        ),
        'shoulder_shrug_seconds': (
          watch: 'Trong Chó Cúi Mặt: vai có xu hướng nhô sát tai khi chịu lực.',
          next: 'Đẩy thảm xa khỏi tai, để hai bả vai trượt rộng sang hai bên.',
        ),
        'leg_straightness_seconds': (
          watch: 'Trong Chó Cúi Mặt: chân mất độ vươn nên hông khó lên cao.',
          next: 'Ấn gót về phía sau và kéo xương ngồi lên cao, gối có thể mềm.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'spine_round_seconds': 'Lưng dài',
        'shoulder_shrug_seconds': 'Vai thả',
        'leg_straightness_seconds': 'Chân vươn',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Lưng dài': (c, t) => 'Giữ lưng dài $c/$t giây - rất ổn.',
        'Vai thả': (c, t) => 'Vai xa tai $c/$t giây - kiểm soát tốt.',
        'Chân vươn': (c, t) => 'Chân vươn tốt $c/$t giây - hông lên đẹp.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
