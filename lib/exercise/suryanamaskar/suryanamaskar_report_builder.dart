import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class SuryanamaskarReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['lumbar_fails_count', 'ashtanga_hip_fails_count'],
        'shoulder': ['downdog_fails_count'],
        'neck': ['cobra_neck_fails_count'],
        'knee': ['lunge_shear_fails_count'],
      };

  @override
  Map<String, String> faultToTipMap() => {
        'lumbar_fails_count':
            'Đẩy hông về trước khi ngả lưng ra sau để bảo vệ thắt lưng.',
        'ashtanga_hip_fails_count':
            'Ở tư thế 8 điểm, nhớ nhô mông lên, không nằm bẹp.',
        'downdog_fails_count':
            'Ép vai xuống và đẩy mạnh tay khi ở Chó cúi mặt.',
        'cobra_neck_fails_count':
            'Hạ vai xuống xa tai, vươn dài cổ khi ở Rắn hổ mang.',
        'lunge_shear_fails_count':
            'Giữ đầu gối thẳng góc với mắt cá ở tư thế Kỵ sĩ.',
        'knee_bend_fails_count':
            'Cố gắng giữ thẳng chân khi gập người để kéo giãn khoeo.',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Flow': (c, t) => 'Hoàn thành mượt mà $c/$t vòng!',
        'Spine': (c, t) => 'Cột sống ổn định $c/$t vòng!',
        'Symmetry': (c, t) => 'Đối xứng tốt $c/$t vòng!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'lumbar_fails_count': 'Spine',
        'symmetry_fails_count': 'Symmetry',
      };

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    final totalGood = allReps.where((r) => r.correctForm).length;

    if (totalReps == 0) return [];

    final accuracy = (totalGood / totalReps * 100).roundToDouble();

    // Flow Score: Dựa trên tỷ lệ rep không bị fault nghiêm trọng
    final flowScore = accuracy;

    // Symmetry Score: Dựa trên tỷ lệ rep không bị fault symmetry
    final totalSymmetryFails = setLoggers.fold(
        0,
        (sum, log) =>
            sum + (log.setLogs['symmetry_fails_count'] as int? ?? 0));
    final symmetryScore =
        ((totalReps - totalSymmetryFails) / totalReps * 100)
            .clamp(0, 100)
            .roundToDouble();

    // Spine Score: Lumbar + Downdog + Cobra
    final totalSpineFails = setLoggers.fold(
        0,
        (sum, log) =>
            sum +
            (log.setLogs['lumbar_fails_count'] as int? ?? 0) +
            (log.setLogs['downdog_fails_count'] as int? ?? 0) +
            (log.setLogs['cobra_neck_fails_count'] as int? ?? 0));
    final spineScore =
        ((totalReps - totalSpineFails) / totalReps * 100)
            .clamp(0, 100)
            .roundToDouble();

    return [
      DetailCard(
        label: 'Flow Score',
        value: '${flowScore.round()}%',
        subLabel: '$totalGood/$totalReps vòng chuẩn',
        useRadial: true,
        radialValue: flowScore,
        color: 'amber',
      ),
      DetailCard(
        label: 'Cột sống',
        value: '${spineScore.round()}%',
        subLabel: 'Không gãy thắt lưng',
        useRadial: true,
        radialValue: spineScore,
        color: 'jade',
      ),
      DetailCard(
        label: 'Đối xứng',
        value: '${symmetryScore.round()}%',
        subLabel: 'P4 vs P9 đều',
        useRadial: true,
        radialValue: symmetryScore,
        color: 'blue',
      ),
    ];
  }

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }
}
