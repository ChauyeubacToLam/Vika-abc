import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class MountainClimberReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['trunk_fails_count'],
        'hip': ['rom_fails_count'],
        'knee': ['rom_fails_count'],
        'shoulder_neck': ['trunk_fails_count'],
        'wrist': ['trunk_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'trunk_fails_count': (
          watch: 'Trong Mountain Climber: thân người có lúc mất trục plank.',
          next:
              'Đẩy sàn ra xa, khóa thân như tấm ván rồi mới kéo từng gối vào.',
        ),
        'rom_fails_count': (
          watch: 'Trong Mountain Climber: gối có lúc kéo chưa đủ sâu.',
          next:
              'Kéo gối về giữa hai khuỷu tay như đang trượt trên một đường ray thẳng.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_fails_count': 'Trục plank',
        'rom_fails_count': 'Biên độ gối',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Trục plank': (c, t) =>
            'Trục plank giữ chắc $c/$t rep - core làm việc rất tốt.',
        'Biên độ gối': (c, t) =>
            'Gối kéo đủ sâu $c/$t rep - nhịp leo núi rõ ràng.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
