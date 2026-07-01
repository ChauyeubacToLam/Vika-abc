import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class TricepDipReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, String> praiseMetricNames() => {
        'hip_thrust_fails_count': 'Cô lập tay sau',
        'rom_fails_count': 'Biên độ gập',
        'extension_fails_count': 'Duỗi thẳng tay',
        'shrugging_fails_count': 'Vai ổn định',
      };

  @override
  Map<String, List<String>> painToFaultMap() => {
        'shoulder_neck': ['shrugging_fails_count'],
        'lower_back': ['hip_thrust_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'hip_thrust_fails_count': (
          watch:
              'Trong Tricep Dip: hông có lúc đẩy lên xuống thay cho chuyển động khuỷu tay.',
          next: 'Gập khuỷu tay lại thay vì đẩy hông lên xuống',
        ),
        'rom_fails_count': (
          watch: 'Trong Tricep Dip: biên độ hạ người có lúc chưa đủ sâu.',
          next: 'Hạ người sâu hơn cho đến khi mông gần chạm sàn',
        ),
        'extension_fails_count': (
          watch: 'Trong Tricep Dip: khuỷu tay có lúc chưa duỗi hết ở đỉnh rep.',
          next: 'Đẩy thẳng tay hoàn toàn ở đỉnh để siết cơ',
        ),
        'shrugging_fails_count': (
          watch: 'Trong Tricep Dip: vai có lúc nhô lên gần tai khi chống đẩy.',
          next: 'Hạ vai xuống, cách xa mang tai',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Cô lập tay sau': (c, t) =>
            'Tay sau làm việc rõ $c/$t rep - hông giữ rất gọn.',
        'Biên độ gập': (c, t) =>
            'Biên độ gập tốt $c/$t rep - lực vào tay sau đều hơn.',
        'Duỗi thẳng tay': (c, t) =>
            'Đỉnh rep duỗi chắc $c/$t rep - kết thúc rất sạch.',
        'Vai ổn định': (c, t) =>
            'Vai giữ xa tai $c/$t rep - cổ và vai nhẹ hơn.',
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
      hipThrustFails +=
          (logger.setLogs['hip_thrust_fails_count'] as num?)?.toInt() ?? 0;
      romFails += (logger.setLogs['rom_fails_count'] as num?)?.toInt() ?? 0;
      extensionFails +=
          (logger.setLogs['extension_fails_count'] as num?)?.toInt() ?? 0;
      shruggingFails +=
          (logger.setLogs['shrugging_fails_count'] as num?)?.toInt() ?? 0;
    }

    final isolationScore =
        ((totalReps - hipThrustFails) / totalReps * 100).roundToDouble();
    final romScore =
        ((totalReps - (romFails + extensionFails)) / totalReps * 100)
            .clamp(0, 100)
            .roundToDouble();
    final stabilityScore =
        ((totalReps - shruggingFails) / totalReps * 100).roundToDouble();

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
