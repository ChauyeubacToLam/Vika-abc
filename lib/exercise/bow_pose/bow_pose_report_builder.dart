import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class BowPoseReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': [
          'lift_form_seconds',
        ],
        'back': ['lift_form_seconds'],
        'shoulder_neck': ['connection_seconds'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'connection_seconds': (
          watch:
              'Trong Bow Pose: kết nối tay và chân có lúc chưa chắc nên tư thế bị kéo lệch.',
          next:
              'Giữ cổ chân như một tay nắm chắc, kéo thảm về hai phía thật đều.',
        ),
        'lift_form_seconds': (
          watch: 'Trong Bow Pose: ngực và đùi chưa nâng lên cùng nhịp an toàn.',
          next:
              'Nâng ngực và đùi như một khối, mắt nhìn xuống mép trước của thảm.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'connection_seconds': 'Kết nối tay-chân',
        'lift_form_seconds': 'Độ nâng',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Kết nối tay-chân': (c, t) =>
            'Kết nối tay-chân chắc $c/$t giây - rất tốt.',
        'Độ nâng': (c, t) => 'Độ nâng kiểm soát $c/$t giây - đẹp.',
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
    final maxHoldTime = _sumDouble(setLoggers, 'max_hold_time');
    final connectionLiftSeconds = _sumDouble(setLoggers, 'connection_seconds') +
        _sumDouble(setLoggers, 'lift_form_seconds');

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
        label: 'Giữ lâu nhất',
        value: '${maxHoldTime.toStringAsFixed(1)}s',
        subLabel: 'Lần giữ dài nhất',
        color: 'jade',
      ),
      DetailCard(
        label: 'Kết nối & nâng',
        value: '${connectionLiftSeconds.toStringAsFixed(1)}s',
        subLabel: 'Tay-chân và độ nâng',
        color: connectionLiftSeconds == 0 ? 'jade' : 'amber',
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
