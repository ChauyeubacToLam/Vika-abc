import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class SphinxReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {};

  @override
  Map<String, String> faultToTipMap() => {};

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {};

  @override
  Map<String, String> praiseMetricNames() => {};

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return [];

    final latestSet = setLoggers.last;
    final holdTime = latestSet.setLogs['active_hold_time'] as double? ?? 0.0;
    final stability = latestSet.setLogs['stability_score'] as double? ?? 0.0;

    final armFails = latestSet.setLogs['straight_arm_fails_count'] as int? ?? 0;
    final armAccuracy = (100.0 - (armFails * 20)).clamp(0.0, 100.0);

    return [
      DetailCard(
        label: 'Thời gian giữ',
        value: '${holdTime.toStringAsFixed(1)}s',
        subLabel: 'Hold Time',
        color: 'jade',
      ),
      DetailCard(
        label: 'Ổn định',
        value: stability.toStringAsFixed(0),
        subLabel: 'Điểm thăng bằng',
        color: 'amber',
        useRadial: true,
        radialValue: stability,
      ),
      DetailCard(
        label: 'Góc tay',
        value: '${armAccuracy.round()}%',
        subLabel: 'Độ chuẩn',
        color: 'jade',
        useRadial: true,
        radialValue: armAccuracy,
      ),
    ];
  }
}
