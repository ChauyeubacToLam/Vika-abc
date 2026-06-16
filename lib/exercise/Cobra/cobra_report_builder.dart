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

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return const [];

    final totalSeconds = _sumDouble(setLoggers, 'total_seconds');
    final goodSeconds = _sumDouble(setLoggers, 'good_seconds');
    final cleanRatio =
        totalSeconds > 0 ? (goodSeconds / totalSeconds * 100) : 0.0;
    final armSeconds = _sumDouble(setLoggers, 'elbow_flexion_seconds') +
        _sumDouble(setLoggers, 'hand_placement_seconds');
    final hipNeckSeconds = _sumDouble(setLoggers, 'pelvic_grounding_seconds') +
        _sumDouble(setLoggers, 'cervical_neutrality_seconds');

    return [
      DetailCard(
        label: 'Giữ sạch',
        value: '${goodSeconds.toStringAsFixed(1)}s',
        subLabel: 'Mục tiêu ${totalSeconds.toStringAsFixed(0)}s',
        useRadial: true,
        radialValue: cleanRatio,
        color: cleanRatio >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Tay & khuỷu',
        value: '${armSeconds.toStringAsFixed(1)}s',
        subLabel: 'Khoá khuỷu hoặc đặt tay sai',
        color: armSeconds == 0 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Hông & cổ',
        value: '${hipNeckSeconds.toStringAsFixed(1)}s',
        subLabel: 'Hông rời sàn hoặc ngửa cổ',
        color: hipNeckSeconds == 0 ? 'jade' : 'ruby',
      ),
    ];
  }

  double _sumDouble(List<ExerciseLogger> setLoggers, String key) {
    return setLoggers.fold<double>(
      0,
      (sum, logger) => sum + ((logger.setLogs[key] as num?)?.toDouble() ?? 0.0),
    );
  }
}
