import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class StepBackBurpeeReportBuilderV2 extends ExerciseReportBuilder {
  @override
  Map<String, String> praiseMetricNames() => {
        'spine_fails_count': 'An toàn cột sống',
        'plank_form_fails_count': 'Form Plank',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'spine_fails_count': (
          watch:
              'Trong Burpee: cột sống chịu áp lực khi hạ người hoặc giữ plank.',
          next:
              'Chùng gối như ngồi xổm khi hạ người, gồng bụng giữ hông không võng ở plank.',
        ),
        'plank_form_fails_count': (
          watch: 'Trong Burpee: bước chân ra sau chưa đủ dài, thân chưa thẳng.',
          next:
              'Bước dứt khoát chân ra sau để kéo dài toàn thân thành một đường thẳng.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'An toàn cột sống': (c, t) =>
            'Cột sống được bảo vệ $c/$t rep - vào ra rất an toàn!',
        'Form Plank': (c, t) => 'Plank thẳng người $c/$t rep - biên độ chuẩn!',
      };

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['spine_fails_count', 'plank_form_fails_count'],
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
