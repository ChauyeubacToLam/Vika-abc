import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class SeatedForwardReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['spine_round_seconds'],
        'back': ['spine_round_seconds'],
        'knee': ['knee_bent_seconds'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'knee_bent_seconds': (
          watch:
              'Trong Seated Forward Fold: gối có xu hướng co lại khi gập sâu hơn.',
          next:
              'Bạn có xu hướng co gối để gập được sâu hơn. Hãy ưu tiên giữ thẳng gối, dù không gập được sâu, cơ gân kheo mới được kéo giãn thực sự.',
        ),
        'spine_round_seconds': (
          watch:
              'Trong Seated Forward Fold: lưng dưới có lúc bo tròn khi gập người.',
          next:
              'Tránh cong lưng thắt lưng. Hãy tưởng tượng bạn đang gập người từ khớp hông (hip hinge) và đẩy ngực về phía trước mũi chân.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Kiểm soát gối thẳng': (count, total) =>
            'Tuyệt vời! Bạn đã giữ đầu gối thẳng tắp trong suốt quá trình tập.',
        'Định tuyến cột sống': (count, total) =>
            'Rất tốt! Cột sống của bạn được căn chỉnh thẳng, bảo vệ an toàn cho đĩa đệm.',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'knee_bent_seconds': 'Kiểm soát gối thẳng',
        'spine_round_seconds': 'Định tuyến cột sống',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return const [];

    final totalSeconds = _sumDouble(setLoggers, 'total_seconds');
    final goodSeconds = _sumDouble(setLoggers, 'good_seconds');
    final cleanRatio =
        totalSeconds > 0 ? (goodSeconds / totalSeconds * 100) : 0.0;
    final kneeSeconds = _sumDouble(setLoggers, 'knee_bent_seconds');
    final spineSeconds = _sumDouble(setLoggers, 'spine_round_seconds');

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
        label: 'Gối co',
        value: '${kneeSeconds.toStringAsFixed(1)}s',
        subLabel: 'Thời gian co gối',
        color: kneeSeconds == 0 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Lưng tròn',
        value: '${spineSeconds.toStringAsFixed(1)}s',
        subLabel: 'Thời gian bo tròn lưng',
        color: spineSeconds == 0 ? 'jade' : 'ruby',
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
