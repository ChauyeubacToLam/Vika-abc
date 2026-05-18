import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/interpreter/interpreter_base.dart';

class PlankUpDownReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
    'lower_back': ['trunk_sagging_fails'],
    'shoulder': ['arm_extension_fails', 'hip_rotation_fails'], // Xoay hông nhiều gây lực vặn lên vai
    'wrist': ['arm_extension_fails'],
  };

  @override
  Map<String, String> faultToTipMap() => {
    'trunk_sagging_fails': 'Võng lưng cực kỳ nguy hiểm. Hãy siết chặt cơ bụng, cuộn xương chậu trước khi đẩy tay.',
    'hip_rotation_fails': 'Lắc hông làm mất tác dụng của Core. Mẹo: Mở rộng 2 chân hơn vai để tạo chân đế vững chắc.',
    'arm_extension_fails': 'Bạn chưa duỗi thẳng tay ở pha High Plank, làm giảm hiệu quả lên cơ tay sau (Tricep).',
  };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) { return null; }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    final totalGood = allReps.where((r) => r.correctForm).length;
    
    if (totalReps == 0) return [];

    // Tính Core Alignment Score (Ví dụ: % số rep không bị lỗi võng lưng)
    final saggingFails = setLoggers.fold(0, (sum, l) => sum + (l.setLogs['trunk_sagging_fails'] as int? ?? 0));
    final coreScore = totalReps > 0 ? ((totalReps - saggingFails) / totalReps * 100).roundToDouble() : 0.0;

    // Check Timeout
    final isTimeout = setLoggers.any((l) => l.setLogs['timeout_triggered'] == true);

    return [
      DetailCard(
        label: 'Tính Ổn Định Lõi (Core)',
        value: '${coreScore.toStringAsFixed(0)}%',
        subLabel: 'Không bị võng lưng',
        useRadial: true,
        radialValue: coreScore,
        color: coreScore > 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Thời gian tập',
        value: isTimeout ? '90s (Timeout)' : 'Hoàn thành',
        subLabel: 'Giới hạn 90s',
        color: isTimeout ? 'rose' : 'jade',
      ),
      DetailCard(
        label: 'Độ chính xác (Form)',
        value: '${((totalGood / totalReps) * 100).round()}%',
        subLabel: '$totalGood/$totalReps reps',
        color: 'blue',
      ),
    ];
  }
}