import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class LungeReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'knee': ['depth_fails_count'],
        'ankle': ['heel_lift_fails_count'],
        'lower_back': [
          'trunk_lean_fails_count',
          'lumbar_proxy_fails_count',
        ],
        'back': ['trunk_lean_fails_count'],
        'hip': ['depth_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'depth_fails_count': (
          watch: 'Trong Lunge: độ sâu có lúc chưa đủ rõ ở đáy rep.',
          next:
              'Hạ người về điểm ngay sau gót chân trước, xuống thêm vừa đủ kiểm soát.',
        ),
        'trunk_lean_fails_count': (
          watch: 'Trong Lunge: thân trên có xu hướng đổ quá xa.',
          next: 'Giữ ngực hướng về một vạch trên tường trước mặt khi đi xuống.',
        ),
        'heel_lift_fails_count': (
          watch: 'Trong Lunge: gót chân trước có lúc nhấc khỏi sàn.',
          next: 'Ép cả dấu chân trước xuống sàn như đang in dấu trên thảm.',
        ),
        'lumbar_proxy_fails_count': (
          watch: 'Trong Lunge: lưng dưới có lúc mất trục khi đổi hướng.',
          next:
              'Giữ xương sườn chồng trên hông, mắt nhìn tới trước một điểm cố định.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'depth_fails_count': 'Độ sâu',
        'trunk_lean_fails_count': 'Thân trên',
        'heel_lift_fails_count': 'Gót chân',
        'lumbar_proxy_fails_count': 'Lưng dưới',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Độ sâu': (c, t) => 'Độ sâu đạt $c/$t rep - chắc đấy.',
        'Thân trên': (c, t) => 'Thân trên giữ gọn $c/$t rep - rất ổn.',
        'Gót chân': (c, t) => 'Gót chân bám sàn $c/$t rep - tốt.',
        'Lưng dưới': (c, t) => 'Lưng dưới ổn định $c/$t rep - kiểm soát tốt.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
