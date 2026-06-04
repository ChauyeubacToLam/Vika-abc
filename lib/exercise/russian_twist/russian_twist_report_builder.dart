import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class RussianTwistReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, String> praiseMetricNames() => {
        'knee_wobble_fails': 'Khóa khung chậu',
        'thoracic_fails': 'Vặn ngực',
        'rom_fails': 'Biên độ vặn',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'knee_wobble_fails': (
          watch: 'Khóa chặt đầu gối, giữ thân dưới đứng im',
          next: 'Khóa chặt đầu gối, giữ thân dưới đứng im',
        ),
        'thoracic_fails': (
          watch: 'Vặn cả bờ vai và ngực thay vì chỉ vung tay',
          next: 'Vặn cả bờ vai và ngực thay vì chỉ vung tay',
        ),
        'rom_fails': (
          watch: 'Vặn sâu hơn, tay phải chạm mép ngoài hông',
          next: 'Vặn sâu hơn, tay phải chạm mép ngoài hông',
        ),
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

    int kneeWobbleFails = 0;
    int thoracicFails = 0;
    int romFails = 0;
    for (final logger in setLoggers) {
      kneeWobbleFails +=
          (logger.setLogs['knee_wobble_fails'] as num?)?.toInt() ?? 0;
      thoracicFails += (logger.setLogs['thoracic_fails'] as num?)?.toInt() ?? 0;
      romFails += (logger.setLogs['rom_fails'] as num?)?.toInt() ?? 0;
    }

    final anchoringScore =
        ((totalReps - kneeWobbleFails) / totalReps * 100).roundToDouble();
    final twistQualityScore =
        ((totalReps - thoracicFails) / totalReps * 100).roundToDouble();
    final romScore = ((totalReps - romFails) / totalReps * 100).roundToDouble();

    return [
      DetailCard(
        label: 'Khóa Khung chậu',
        value: '${anchoringScore.round()}%',
        subLabel: 'Giữ gối cố định',
        useRadial: true,
        radialValue: anchoringScore,
        color: anchoringScore >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Chất lượng vặn ngực',
        value: '${twistQualityScore.round()}%',
        subLabel: 'Vặn cả vai',
        useRadial: true,
        radialValue: twistQualityScore,
        color: twistQualityScore >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Biên độ vặn',
        value: '${romScore.round()}%',
        subLabel: 'Qua giới hạn hông',
        useRadial: true,
        radialValue: romScore,
        color: romScore >= 80 ? 'jade' : 'amber',
      ),
    ];
  }
}
