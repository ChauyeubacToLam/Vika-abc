import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class WalkingLungeReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'knee': ['front_knee_fails_count'],
        'hip': ['rear_depth_fails_count'],
        'lower_back': ['torso_lean_fails_count'],
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'front_knee_fails_count': 'Kiểm soát gối',
        'step_consistency_fails_count': 'Sải bước',
        'torso_lean_fails_count': 'Lưng thẳng',
        'rear_depth_fails_count': 'Độ sâu gối sau',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'front_knee_fails_count': (
          watch: 'Trong Lunge: gối trước có lúc vượt quá mũi chân.',
          next: 'Bước chân dài hơn, không để gối đâm về trước',
        ),
        'step_consistency_fails_count': (
          watch: 'Trong Lunge: độ dài sải bước chưa đều giữa các rep.',
          next: 'Duy trì khoảng cách bước đều đặn',
        ),
        'torso_lean_fails_count': (
          watch: 'Trong Lunge: thân trên có lúc đổ về trước.',
          next: 'Giữ lưng thẳng đứng trong suốt bài tập',
        ),
        'rear_depth_fails_count': (
          watch: 'Trong Lunge: đầu gối sau chưa hạ đủ sâu.',
          next: 'Hạ gối sau xuống gần sàn hơn, tạo góc 90 độ ở cả hai chân.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Kiểm soát gối': (c, t) =>
            'Gối trước kiểm soát tốt $c/$t rep - không vượt mũi chân!',
        'Sải bước': (c, t) => 'Sải bước đều $c/$t rep - nhịp di chuyển ổn!',
        'Lưng thẳng': (c, t) =>
            'Thân trên thẳng $c/$t rep - giữ thăng bằng tốt!',
        'Độ sâu gối sau': (c, t) => 'Gối sau hạ sâu $c/$t rep - biên độ chuẩn!',
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
      stepFails +=
          (logger.setLogs['step_consistency_fails_count'] as num?)?.toInt() ?? 0;
      kneeFails += (logger.setLogs['front_knee_fails_count'] as num?)?.toInt() ?? 0;
      torsoFails += (logger.setLogs['torso_lean_fails_count'] as num?)?.toInt() ?? 0;
    }

    final strideScore =
        ((totalReps - stepFails) / totalReps * 100).roundToDouble();
    final kneeScore =
        ((totalReps - kneeFails) / totalReps * 100).roundToDouble();
    final torsoScore =
        ((totalReps - torsoFails) / totalReps * 100).roundToDouble();

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
