import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class SupermanReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['lumbar_fails_count', 'hip_fails_count'],
        'shoulder_neck': ['elevation_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'elevation_fails_count': (
          watch:
              'Trong Superman: tay và chân có lúc nâng không đều khi giữ đỉnh.',
          next:
              'Nâng đồng thời cả tay và chân, không để một bên rơi xuống khi giữ.',
        ),
        'hip_fails_count': (
          watch: 'Trong Superman: hông có lúc nhấc khỏi sàn khi vào tư thế.',
          next:
              'Giữ hông làm điểm tựa, tránh nhấc hông lên khỏi sàn khi vào tư thế.',
        ),
        'hold_fails_count': (
          watch:
              'Trong Superman: thời gian giữ ở điểm cao nhất có lúc chưa đủ lâu.',
          next: 'Giữ ở điểm cao nhất đủ lâu hơn, lên chậm và không giật cục.',
        ),
        'lumbar_fails_count': (
          watch:
              'Trong Superman: lưng dưới có lúc uốn quá gắt khi nâng tay chân.',
          next:
              'Giảm độ nâng tay chân một chút để cột sống thắt lưng không bị uốn quá gắt.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'elevation_fails_count': 'Độ nâng tay chân',
        'hold_fails_count': 'Thời gian giữ',
        'lumbar_fails_count': 'An toàn lưng',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Độ nâng tay chân': (c, t) =>
            'Tay chân nâng đều $c/$t rep - đường bay rất gọn.',
        'Thời gian giữ': (c, t) =>
            'Giữ đỉnh chắc $c/$t rep - kiểm soát tốt hơn hẳn.',
        'An toàn lưng': (c, t) =>
            'Lưng dưới an toàn $c/$t rep - độ nâng vừa đủ và sạch.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    if (allReps.isEmpty) return [];

    final totalReps = allReps.length;
    final goodReps = allReps.where((r) => r.correctForm).length;
    final quality = (goodReps / totalReps * 100).roundToDouble();

    final holdDurations = allReps
        .map((r) => (r.data['hold_time'] as num?)?.toDouble() ?? 0.0)
        .where((v) => v > 0)
        .toList();
    final avgHold = holdDurations.isEmpty
        ? 0.0
        : holdDurations.reduce((a, b) => a + b) / holdDurations.length;

    final lumbarFails = setLoggers.fold<int>(
      0,
      (sum, logger) =>
          sum + ((logger.setLogs['lumbar_fails_count'] as num?)?.toInt() ?? 0),
    );

    return [
      DetailCard(
        label: 'Độ chính xác',
        value: '${quality.round()}%',
        subLabel: '$goodReps/$totalReps rep đúng form',
        useRadial: true,
        radialValue: quality,
        color: quality >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Thời gian giữ trung bình',
        value: '${avgHold.toStringAsFixed(1)}s',
        subLabel: 'Mục tiêu: 2.0s',
        color: avgHold >= 2.0 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'An toàn lưng',
        value: lumbarFails == 0 ? 'Ổn' : '$lumbarFails lỗi',
        subLabel: 'Tránh uốn lưng quá gắt',
        color: lumbarFails == 0 ? 'jade' : 'rose',
      ),
    ];
  }
}
