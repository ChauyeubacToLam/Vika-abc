import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class StandingKneeToElbowReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'knee': ['knee_valgus_fails_count'],
        'hip': ['pelvic_drop_fails_count', 'core_drive_fails_count'],
        'lower_back': ['cross_rom_fails_count'],
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'knee_valgus_fails_count': 'Ổn định gối trụ',
        'core_drive_fails_count': 'Nâng đùi',
        'cross_rom_fails_count': 'Chạm chéo',
        'pelvic_drop_fails_count': 'Vững hông',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'knee_valgus_fails_count': (
          watch: 'Trong bài này: gối chân trụ có lúc đổ vào trong.',
          next: 'Gồng chặt chân trụ, mở gối ra ngoài',
        ),
        'core_drive_fails_count': (
          watch: 'Trong bài này: đùi chưa nâng đủ cao ở một số rep.',
          next: 'Nhấc cao đùi lên bằng cơ bụng, đừng rụt cổ',
        ),
        'cross_rom_fails_count': (
          watch: 'Trong bài này: tay và gối chưa chạm tới nhau.',
          next: 'Vặn người mạnh hơn, cho tay chạm gối',
        ),
        'pelvic_drop_fails_count': (
          watch:
              'Trong bài này: hông có lúc bị sụp về một bên khi đứng một chân.',
          next: 'Gồng mông chân trụ, giữ hai bên hông ngang bằng nhau.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Ổn định gối trụ': (c, t) =>
            'Gối trụ ổn định $c/$t rep - không đổ vào trong!',
        'Nâng đùi': (c, t) => 'Nâng đùi cao $c/$t rep - cơ bụng làm việc tốt!',
        'Chạm chéo': (c, t) =>
            'Vặn người chạm gối $c/$t rep - biên độ rất tốt!',
        'Vững hông': (c, t) =>
            'Hông giữ ngang bằng $c/$t rep - chân trụ rất vững!',
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

    int kneeValgusFails = 0;
    int coreDriveFails = 0;
    int crossRomFails = 0;
    for (final logger in setLoggers) {
      kneeValgusFails +=
          (logger.setLogs['knee_valgus_fails_count'] as num?)?.toInt() ?? 0;
      coreDriveFails +=
          (logger.setLogs['core_drive_fails_count'] as num?)?.toInt() ?? 0;
      crossRomFails +=
          (logger.setLogs['cross_rom_fails_count'] as num?)?.toInt() ?? 0;
    }

    final kneeSafetyScore =
        ((totalReps - kneeValgusFails) / totalReps * 100).roundToDouble();
    final coreDriveScore =
        ((totalReps - coreDriveFails) / totalReps * 100).roundToDouble();
    final crossRomScore =
        ((totalReps - crossRomFails) / totalReps * 100).roundToDouble();

    return [
      DetailCard(
        label: 'Ổn định Khớp Gối',
        value: '${kneeSafetyScore.round()}%',
        subLabel: 'Không sụp gối',
        useRadial: true,
        radialValue: kneeSafetyScore,
        color: kneeSafetyScore >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Độ gập cốt lõi',
        value: '${coreDriveScore.round()}%',
        subLabel: 'Nâng cao đùi',
        useRadial: true,
        radialValue: coreDriveScore,
        color: coreDriveScore >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Biên độ chạm chéo',
        value: '${crossRomScore.round()}%',
        subLabel: 'Tay chạm gối',
        useRadial: true,
        radialValue: crossRomScore,
        color: crossRomScore >= 80 ? 'jade' : 'amber',
      ),
    ];
  }
}
