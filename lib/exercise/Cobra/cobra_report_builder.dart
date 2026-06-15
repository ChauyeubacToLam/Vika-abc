import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class CobraReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'shoulder_neck': [
          'elbow_flexion_seconds',
          'cervical_neutrality_seconds',
        ],
        'lower_back': [
          'pelvic_grounding_seconds',
        ],
        'hip': ['pelvic_grounding_seconds'],
        'wrist': [
          'elbow_flexion_seconds',
          'hand_placement_seconds',
        ],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'elbow_flexion_seconds': (
          watch: 'Trong Cobra: khuỷu tay có lúc khóa quá thẳng.',
          next:
              'Đẩy sàn nhẹ và giữ khuỷu tay mềm, để ngực mở mà vai không gồng.',
        ),
        'hand_placement_seconds': (
          watch: 'Trong Cobra: vị trí tay làm vai phải gánh nhiều hơn.',
          next:
              'Kéo lòng bàn tay về gần xương sườn, rồi đẩy thảm ra xa thật nhẹ.',
        ),
        'cervical_neutrality_seconds': (
          watch: 'Trong Cobra: cổ có xu hướng ngửa quá nhiều.',
          next:
              'Nhìn xuống mép thảm phía trước, giữ gáy dài như đang đội một cuốn sách.',
        ),
        'pelvic_grounding_seconds': (
          watch: 'Trong Cobra: hông có lúc rời khỏi thảm.',
          next:
              'Neo xương hông xuống thảm trước, rồi để ngực trượt dài về phía trước.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'elbow_flexion_seconds': 'Khuỷu tay mềm',
        'hand_placement_seconds': 'Vị trí tay',
        'cervical_neutrality_seconds': 'Cổ trung tính',
        'pelvic_grounding_seconds': 'Hông neo sàn',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Khuỷu tay mềm': (c, t) =>
            'Khuỷu tay giữ mềm $c/$t giây - vai nhẹ hơn nhiều.',
        'Vị trí tay': (c, t) =>
            'Tay đặt chắc $c/$t giây - lực đẩy vào thảm rất gọn.',
        'Cổ trung tính': (c, t) => 'Cổ giữ dài $c/$t giây - nhìn rất an toàn.',
        'Hông neo sàn': (c, t) =>
            'Hông neo xuống thảm $c/$t giây - Cobra có kiểm soát.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
