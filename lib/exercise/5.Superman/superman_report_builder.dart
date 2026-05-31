import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class SupermanReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['lumbar_fails', 'hip_fails'],
        'shoulder': ['elevation_fails'],
      };

  @override
  Map<String, String> faultToTipMap() => {
        'elevation_fails':
            'Nâng đồng thời cả tay và chân, không để một bên rơi xuống khi giữ.',
        'hip_fails':
            'Giữ hông làm điểm tựa, tránh nhấc hông lên khỏi sàn khi vào tư thế.',
        'hold_fails':
            'Giữ ở điểm cao nhất đủ lâu hơn, lên chậm và không giật cục.',
        'lumbar_fails':
            'Giảm độ nâng tay chân một chút để cột sống thắt lưng không bị uốn quá gắt.',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'elevation_fails': 'Độ nâng tay chân',
        'hold_fails': 'Thời gian giữ',
        'lumbar_fails': 'An toàn lưng',
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
          sum + ((logger.setLogs['lumbar_fails'] as num?)?.toInt() ?? 0),
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
