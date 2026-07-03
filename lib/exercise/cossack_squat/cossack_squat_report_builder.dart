import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class CossackSquatReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'knee': ['knee_valgus_fails_count', 'depth_fails_count'],
        'ankle': ['heel_lift_fails_count'],
        'hip': ['straight_leg_fails_count'],
        'lower_back': ['torso_lean_fails_count'],
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'knee_valgus_fails_count': 'Ổn định gối',
        'heel_lift_fails_count': 'Gót chân',
        'depth_fails_count': 'Độ sâu',
        'straight_leg_fails_count': 'Chân duỗi',
        'torso_lean_fails_count': 'Lưng thẳng',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'knee_valgus_fails_count': (
          watch: 'Trong Cossack: đầu gối có lúc đổ vào trong khi hạ xuống.',
          next: 'Mở đầu gối ra ngoài khi ngồi xuống',
        ),
        'heel_lift_fails_count': (
          watch: 'Trong Cossack: gót chân có lúc nhấc khỏi sàn.',
          next: 'Giữ gót chân chạm sàn trong suốt bài tập',
        ),
        'depth_fails_count': (
          watch: 'Trong Cossack: độ sâu chưa đạt ở một số rep.',
          next: 'Cố gắng ngồi sâu hơn nữa, mông sát gót',
        ),
        'straight_leg_fails_count': (
          watch: 'Trong Cossack: chân duỗi có lúc bị chùng gối.',
          next: 'Giữ chân duỗi thẳng hết cỡ, mũi chân hướng lên trần.',
        ),
        'torso_lean_fails_count': (
          watch: 'Trong Cossack: thân trên có lúc đổ về trước.',
          next: 'Ưỡn ngực và giữ lưng thẳng đứng khi hạ người xuống.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Ổn định gối': (c, t) => 'Gối ổn định $c/$t rep - không đổ vào trong!',
        'Gót chân': (c, t) => 'Gót chân chạm sàn $c/$t rep - chắc chắn!',
        'Độ sâu': (c, t) => 'Ngồi sâu $c/$t rep - biên độ tốt!',
        'Chân duỗi': (c, t) => 'Chân duỗi thẳng $c/$t rep - mở háng rất tốt!',
        'Lưng thẳng': (c, t) =>
            'Lưng giữ thẳng $c/$t rep - thân trên rất vững!',
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
      kneeValgusFails +=
          (logger.setLogs['knee_valgus_fails_count'] as num?)?.toInt() ?? 0;
      depthFails += (logger.setLogs['depth_fails_count'] as num?)?.toInt() ?? 0;
    }

    final kneeScore =
        ((totalReps - kneeValgusFails) / totalReps * 100).roundToDouble();
    final depthScore =
        ((totalReps - depthFails) / totalReps * 100).roundToDouble();
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
