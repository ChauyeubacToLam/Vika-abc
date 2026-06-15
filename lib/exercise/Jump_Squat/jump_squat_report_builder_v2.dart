import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class JumpSquatReportBuilderV2 extends ExerciseReportBuilder {
  @override
  Map<String, String> praiseMetricNames() => {
        'stiff_landing_fails_count': 'Tiếp đất êm',
        'shallow_dip_fails_count': 'Độ nén',
        'trunk_lean_fails_count': 'Thân trên',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'stiff_landing_fails_count': (
          watch: 'Trong Jump Squat: có lúc tiếp đất với chân hơi cứng.',
          next:
              'Tiếp đất nhẹ bằng nửa bàn chân trước rồi chùng gối để giảm xóc cho khớp.',
        ),
        'shallow_dip_fails_count': (
          watch: 'Trong Jump Squat: nhịp lấy đà chưa đủ sâu.',
          next: 'Hạ hông sâu hơn trước khi bật để dồn lực vào mông và đùi.',
        ),
        'trunk_lean_fails_count': (
          watch: 'Trong Jump Squat: thân trên đổ về trước khi tiếp đất.',
          next:
              'Mở ngực, nhìn thẳng về trước khi chạm đất để dồn tải vào chân.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Tiếp đất êm': (c, t) =>
            'Tiếp đất êm $c/$t rep - khớp gối được bảo vệ tốt!',
        'Độ nén': (c, t) => 'Lấy đà đủ sâu $c/$t rep - lực bật rất mạnh!',
        'Thân trên': (c, t) =>
            'Thân trên vững $c/$t rep - kiểm soát tốt khi tiếp đất!',
      };

  @override
  Map<String, List<String>> painToFaultMap() => {
        'knee': ['stiff_landing_fails_count', 'shallow_dip_fails_count'],
        'ankle': ['stiff_landing_fails_count'],
        'lower_back': ['trunk_lean_fails_count'],
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
