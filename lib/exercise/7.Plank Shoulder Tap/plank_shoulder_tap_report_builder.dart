import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class PlankShoulderTapReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['rotation_fails', 'alignment_fails'], // Vặn hông/Võng lưng dồn áp lực đĩa đệm
        'wrist': ['tempo_fails'], // Tập quá nhanh/giật cục đập cổ tay xuống sàn
        'shoulder': ['rotation_fails'],
      };

  @override
  Map<String, String> faultToTipMap() => {
        'rotation_fails': 'Mở rộng hai chân hơn vai để tăng chân đế (Base of support). Siết chặt bụng, không để hông lắc lư khi nhấc tay.',
        'alignment_fails': 'Không chổng mông hay võng lưng. Cơ thể phải là một đường thẳng căng cứng.',
        'tap_fails': 'Chạm tay dứt khoát lên vai đối diện để kiểm soát trọng tâm tốt hơn.',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'AntiRot': (c, t) => 'Hông đóng băng, chống xoay cực tốt $c/$t rep!',
        'Alignment': (c, t) => 'Trục lưng thẳng tắp $c/$t rep!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'rotation_fails': 'AntiRot',
        'alignment_fails': 'Alignment',
      };

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    
    if (totalReps == 0) return [];

    // Điểm Chống Xoay (Anti-Rotation Score)
    int totalRotFails = setLoggers.fold(0, (sum, log) => sum + (log.setLogs['rotation_fails'] as int? ?? 0));
    double rotScore = ((totalReps - totalRotFails) / totalReps * 100).clamp(0, 100).roundToDouble();

    // Điểm Ổn định cốt lõi (Core Alignment)
    int totalAlignFails = setLoggers.fold(0, (sum, log) => sum + (log.setLogs['alignment_fails'] as int? ?? 0));
    double alignScore = ((totalReps - totalAlignFails) / totalReps * 100).clamp(0, 100).roundToDouble();

    // Tỷ lệ chạm vai hoàn hảo (Clear Tap Rate)
    int totalTapFails = setLoggers.fold(0, (sum, log) => sum + (log.setLogs['tap_fails'] as int? ?? 0));
    double tapScore = ((totalReps - totalTapFails) / totalReps * 100).clamp(0, 100).roundToDouble();

    return [
      DetailCard(
        label: 'Điểm Chống Xoay',
        value: '${rotScore.round()}%',
        subLabel: 'Hông đóng băng',
        useRadial: true,
        radialValue: rotScore,
        color: 'amber',
      ),
      DetailCard(
        label: 'Độ Ổn Định Lõi',
        value: '${alignScore.round()}%',
        subLabel: 'Lưng thẳng tắp',
        useRadial: true,
        radialValue: alignScore,
        color: 'jade',
      ),
      DetailCard(
        label: 'Chạm Hoàn Hảo',
        value: '${tapScore.round()}%',
        subLabel: 'Biên độ chuẩn',
        useRadial: true,
        radialValue: tapScore,
        color: 'blue',
      ),
    ];
  }
  
  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }
}