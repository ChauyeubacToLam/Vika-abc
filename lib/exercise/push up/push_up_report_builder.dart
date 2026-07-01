import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class PushUpReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['trunk_alignment_fails_count'],
        'shoulder_neck': [
          'depth_fails_count',
          'tempo_fails_count',
        ],
        'wrist': [
          'depth_fails_count',
          'tempo_fails_count',
        ],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'trunk_alignment_fails_count': (
          watch: 'Trong Push Up: thân người có lúc võng hoặc chổng hông.',
          next:
              'Đẩy sàn ra xa, kéo khóa quần về rốn và giữ vai-hông-gót trên một đường.',
        ),
        'depth_fails_count': (
          watch: 'Trong Push Up: độ sâu có lúc chưa đủ rõ.',
          next:
              'Hạ ngực về một điểm giữa hai bàn tay, chạm đáy rồi đẩy sàn đi.',
        ),
        'tempo_fails_count': (
          watch: 'Trong Push Up: nhịp hạ có lúc hơi vội.',
          next: 'Đi xuống như thang máy chậm, đếm một-nhẹ-hai rồi mới đẩy lên.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_alignment_fails_count': 'Thân người',
        'depth_fails_count': 'Độ sâu',
        'tempo_fails_count': 'Nhịp hạ',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Thân người': (c, t) =>
            'Thân người giữ thẳng $c/$t rep - lực đẩy sạch hơn hẳn.',
        'Độ sâu': (c, t) => 'Độ sâu đạt $c/$t rep - rất có chất lượng.',
        'Nhịp hạ': (c, t) =>
            'Nhịp hạ kiểm soát $c/$t rep - vai và cổ tay được chăm tốt.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
