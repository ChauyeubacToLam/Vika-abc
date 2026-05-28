import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class TricepDipReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, String> praiseMetricNames() => {
        'hip_thrust_fails': 'Cô lập tay sau',
        'rom_fails': 'Biên độ gập',
        'extension_fails': 'Duỗi thẳng tay',
        'shrugging_fails': 'Vai ổn định',
      };

  @override
  Map<String, String> faultToTipMap() => {
        'hip_thrust_fails': 'Gập khuỷu tay lại thay vì đẩy hông lên xuống',
        'rom_fails': 'Hạ người sâu hơn cho đến khi mông gần chạm sàn',
        'extension_fails': 'Đẩy thẳng tay hoàn toàn ở đỉnh để siết cơ',
        'shrugging_fails': 'Hạ vai xuống, cách xa mang tai',
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

    int hipThrustFails = 0;
    int romFails = 0;
    int extensionFails = 0;
    int shruggingFails = 0;
    for (final logger in setLoggers) {
      hipThrustFails += (logger.setLogs['hip_thrust_fails'] as num?)?.toInt() ?? 0;
      romFails += (logger.setLogs['rom_fails'] as num?)?.toInt() ?? 0;
      extensionFails += (logger.setLogs['extension_fails'] as num?)?.toInt() ?? 0;
      shruggingFails += (logger.setLogs['shrugging_fails'] as num?)?.toInt() ?? 0;
    }

    final isolationScore = ((totalReps - hipThrustFails) / totalReps * 100).roundToDouble();
    final romScore = ((totalReps - (romFails + extensionFails)) / totalReps * 100).clamp(0, 100).roundToDouble();
    final stabilityScore = ((totalReps - shruggingFails) / totalReps * 100).roundToDouble();

    return [
      DetailCard(
        label: 'Độ cô lập tay sau',
        value: '${isolationScore.round()}%',
        subLabel: 'Không đẩy hông',
        useRadial: true,
        radialValue: isolationScore,
        color: isolationScore >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Biên độ tối đa',
        value: '${romScore.round()}%',
        subLabel: 'Duỗi gập sâu',
        useRadial: true,
        radialValue: romScore,
        color: romScore >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Kiểm soát bả vai',
        value: '${stabilityScore.round()}%',
        subLabel: 'Không rụt cổ',
        useRadial: true,
        radialValue: stabilityScore,
        color: stabilityScore >= 80 ? 'jade' : 'amber',
      ),
    ];
  }
}
