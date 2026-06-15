import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class PlankShoulderTapReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['rotation_fails_count', 'alignment_fails_count'],
        'hip': ['rotation_fails_count'],
        'shoulder_neck': ['tap_fails_count', 'tempo_fails_count'],
        'wrist': ['tempo_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'rotation_fails_count': (
          watch: 'Trong Plank Shoulder Tap: hông có lúc xoay khi nhấc tay.',
          next:
              'Mở chân rộng hơn vai, đẩy sàn ra xa và giữ hông đứng yên trước khi chạm vai.',
        ),
        'alignment_fails_count': (
          watch: 'Trong Plank Shoulder Tap: thân người có lúc mất đường thẳng.',
          next:
              'Kéo rốn lên khỏi sàn, siết mông nhẹ và giữ vai-hông-gót trên một đường.',
        ),
        'tap_fails_count': (
          watch: 'Trong Plank Shoulder Tap: có nhịp chạm vai chưa rõ.',
          next:
              'Chạm tay dứt khoát vào vai đối diện như bấm một nút nhỏ rồi trả tay về sàn.',
        ),
        'tempo_fails_count': (
          watch: 'Trong Plank Shoulder Tap: nhịp chạm có lúc quá nhanh.',
          next: 'Nâng tay như đi qua mật ong, chạm vai rồi đặt tay xuống êm.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'rotation_fails_count': 'Chống xoay',
        'alignment_fails_count': 'Trục thân',
        'tap_fails_count': 'Chạm vai',
        'tempo_fails_count': 'Nhịp chạm',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Chống xoay': (c, t) =>
            'Hông chống xoay $c/$t rep - nền plank rất chắc.',
        'Trục thân': (c, t) => 'Trục thân thẳng $c/$t rep - core giữ tốt.',
        'Chạm vai': (c, t) =>
            'Chạm vai rõ $c/$t rep - kiểm soát trọng tâm đẹp.',
        'Nhịp chạm': (c, t) =>
            'Nhịp chạm êm $c/$t rep - cổ tay được đặt xuống nhẹ.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
