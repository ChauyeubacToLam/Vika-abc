import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class MountainClimberReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['trunk_fails_count'], // Đau lưng dưới do võng lưng
        'shoulder': ['trunk_fails_count'], // Setup tay sai
        'wrist': ['trunk_fails_count'],
      };

  @override
  Map<String, String> faultToTipMap() => {
        'trunk_fails_count': 'Siết chặt cơ bụng, cuộn xương cụt nhẹ xuống để khóa form lưng thẳng.',
        'rom_fails_count': 'Cố gắng kéo gối cao ngang rốn hoặc sát khuỷu tay để đốt mỡ hiệu quả hơn.',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Core': (c, t) => 'Giữ form cực đỉnh $c/$t rep!',
        'ROM': (c, t) => 'Biên độ sâu $c/$t rep, rất ăn bụng!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_fails_count': 'Core',
        'rom_fails_count': 'ROM',
      };

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    final totalGood = allReps.where((r) => r.correctForm).length;
    
    if (totalReps == 0) return [];

    final accuracy = (totalGood / totalReps * 100).roundToDouble();
    
    // Core Stability Score giả lập dựa trên tỷ lệ lỗi trunk (càng ít lỗi điểm càng cao)
    int totalTrunkFails = setLoggers.fold(0, (sum, log) => sum + (log.setLogs['trunk_fails_count'] as int? ?? 0));
    double coreScore = ((totalReps - totalTrunkFails) / totalReps * 100).clamp(0, 100).roundToDouble();

    return [
      DetailCard(
        label: 'Độ Ổn Định Core',
        value: '${coreScore.round()}%',
        subLabel: 'Không võng lưng',
        useRadial: true,
        radialValue: coreScore,
        color: 'amber',
      ),
      DetailCard(
        label: 'Tỷ lệ chính xác',
        value: '${accuracy.round()}%',
        subLabel: '$totalGood/$totalReps rep',
        useRadial: true,
        radialValue: accuracy,
        color: 'jade',
      ),
      DetailCard(
        label: 'Reps đạt chuẩn',
        value: '$totalGood',
        subLabel: 'ROM tốt',
        color: 'blue',
      ),
    ];
  }
  
  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null; // Có thể mở rộng Interpreter ở đây
  }
}