import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class CossackSquatReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, String> praiseMetricNames() => {
        'knee_valgus_fails': 'Ổn định gối',
        'heel_lift_fails': 'Gót chân',
        'depth_fails': 'Độ sâu',
      };

  @override
  Map<String, String> faultToTipMap() => {
        'knee_valgus_fails': 'Mở đầu gối ra ngoài khi ngồi xuống',
        'heel_lift_fails': 'Giữ gót chân chạm sàn trong suốt bài tập',
        'depth_fails': 'Cố gắng ngồi sâu hơn nữa, mông sát gót',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null; // No interpreter for this exercise yet
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    final totalGood = allReps.where((r) => r.correctForm).length;

    if (totalReps == 0) return [];

    int kneeValgusFails = 0;
    int depthFails = 0;
    for (final logger in setLoggers) {
      kneeValgusFails += (logger.setLogs['knee_valgus_fails'] as num?)?.toInt() ?? 0;
      depthFails += (logger.setLogs['depth_fails'] as num?)?.toInt() ?? 0;
    }

    final kneeScore = ((totalReps - kneeValgusFails) / totalReps * 100).roundToDouble();
    final depthScore = ((totalReps - depthFails) / totalReps * 100).roundToDouble();
    final accuracy = (totalGood / totalReps * 100).roundToDouble();

    return [
      DetailCard(
        label: 'Ổn định gối',
        value: '${kneeScore.round()}%',
        subLabel: '${totalReps - kneeValgusFails}/$totalReps rep',
        useRadial: true,
        radialValue: kneeScore,
        color: kneeScore >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Độ sâu & Linh hoạt',
        value: '${depthScore.round()}%',
        subLabel: '${totalReps - depthFails}/$totalReps rep',
        useRadial: true,
        radialValue: depthScore,
        color: depthScore >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Độ chính xác',
        value: '${accuracy.round()}%',
        subLabel: '$totalGood/$totalReps rep',
        useRadial: true,
        radialValue: accuracy,
        color: 'jade',
      ),
    ];
  }
}
