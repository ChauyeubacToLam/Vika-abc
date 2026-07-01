import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class SidePlankDipReportBuilderV2 extends ExerciseReportBuilder {
  @override
  Map<String, String> praiseMetricNames() => {
        'shoulder_align_fails_count': 'Vai an toàn',
        'rotation_fails_count': 'Chống xoay',
        'dip_depth_fails_count': 'Đường thẳng thân người',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'shoulder_align_fails_count': (
          watch: 'Trong Side Plank: khuỷu tay có lúc lệch khỏi trục dưới vai.',
          next: 'Đặt khuỷu tay thẳng ngay dưới vai trước khi bắt đầu hạ hông.',
        ),
        'rotation_fails_count': (
          watch: 'Trong Side Plank: thân người có lúc bị đổ về trước hoặc sau.',
          next:
              'Tưởng tượng lưng tựa phẳng vào tường, giữ thân thẳng thành một mặt phẳng.',
        ),
        'dip_depth_fails_count': (
          watch: 'Trong Side Plank: hông có lúc hạ khỏi đường thẳng cơ thể.',
          next: 'Nâng hông để vai, hông và cổ chân nằm trên một đường thẳng.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Vai an toàn': (c, t) =>
            'Khuỷu tay thẳng trục $c/$t rep - khớp vai an toàn!',
        'Chống xoay': (c, t) =>
            'Thân giữ phẳng $c/$t rep - cơ lõi kiểm soát tốt!',
        'Đường thẳng thân người': (c, t) =>
            'Giữ thân thẳng ổn định trong $c/$t hiệp!',
      };

  @override
  Map<String, List<String>> painToFaultMap() => {
        'shoulder_neck': ['shoulder_align_fails_count'],
        'lower_back': ['rotation_fails_count'],
        'hip': ['dip_depth_fails_count'],
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
