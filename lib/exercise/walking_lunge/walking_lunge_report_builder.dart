import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class WalkingLungeReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, String> praiseMetricNames() => {
        'front_knee_fails': 'Kiểm soát gối',
        'step_consistency_fails': 'Sải bước',
        'torso_lean_fails': 'Lưng thẳng',
      };

  @override
  Map<String, String> faultToTipMap() => {
        'front_knee_fails': 'Bước chân dài hơn, không để gối đâm về trước',
        'step_consistency_fails': 'Duy trì khoảng cách bước đều đặn',
        'torso_lean_fails': 'Giữ lưng thẳng đứng trong suốt bài tập',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    if (totalReps == 0) return [];

    int stepFails = 0;
    int kneeFails = 0;
    int torsoFails = 0;
    for (final logger in setLoggers) {
      stepFails += (logger.setLogs['step_consistency_fails'] as num?)?.toInt() ?? 0;
      kneeFails += (logger.setLogs['front_knee_fails'] as num?)?.toInt() ?? 0;
      torsoFails += (logger.setLogs['torso_lean_fails'] as num?)?.toInt() ?? 0;
    }

    final strideScore = ((totalReps - stepFails) / totalReps * 100).roundToDouble();
    final kneeScore = ((totalReps - kneeFails) / totalReps * 100).roundToDouble();
    final torsoScore = ((totalReps - torsoFails) / totalReps * 100).roundToDouble();

    return [
      DetailCard(
        label: 'Nhịp độ sải bước',
        value: '${strideScore.round()}%',
        subLabel: 'Bước đều đặn',
        useRadial: true,
        radialValue: strideScore,
        color: strideScore >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'An toàn Khớp gối',
        value: '${kneeScore.round()}%',
        subLabel: 'Kiểm soát gối trước',
        useRadial: true,
        radialValue: kneeScore,
        color: kneeScore >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Độ thẳng thân trên',
        value: '${torsoScore.round()}%',
        subLabel: 'Không đổ người',
        useRadial: true,
        radialValue: torsoScore,
        color: torsoScore >= 80 ? 'jade' : 'amber',
      ),
    ];
  }
}
