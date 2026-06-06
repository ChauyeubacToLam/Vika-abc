import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class PlankReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['trunk_fails_count'],
        'neck': ['neck_fails_count'],
        'knee': ['knee_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'trunk_fails_count': (
          watch: 'Giữ hông nằm trên một đường thẳng với vai và cổ chân.',
          next: 'Ép nhẹ khuỷu tay xuống sàn và siết bụng trước khi giữ.',
        ),
        'neck_fails_count': (
          watch: 'Đầu và cổ cần đi cùng đường với thân người.',
          next: 'Nhìn xuống sàn, giữ gáy dài thay vì ngẩng hoặc cúi đầu.',
        ),
        'knee_fails_count': (
          watch: 'Gối gập làm bài plank nhẹ đi và giảm hiệu quả cơ lõi.',
          next: 'Đẩy gót ra sau để khóa gối và giữ thân người dài.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_fails_count': 'Trục thân',
        'neck_fails_count': 'Cổ vai',
        'knee_fails_count': 'Gối',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Trục thân': (c, t) => 'Trục thân ổn định trong $c/$t giây.',
        'Cổ vai': (c, t) => 'Cổ vai giữ gọn trong $c/$t giây.',
        'Gối': (c, t) => 'Gối giữ thẳng trong $c/$t giây.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return const [];
    final totalSeconds = setLoggers.fold<double>(
      0,
      (sum, logger) =>
          sum + ((logger.setLogs['total_seconds'] as num?)?.toDouble() ?? 0.0),
    );
    final goodSeconds = setLoggers.fold<double>(
      0,
      (sum, logger) =>
          sum + ((logger.setLogs['good_seconds'] as num?)?.toDouble() ?? 0.0),
    );
    final cleanRatio =
        totalSeconds > 0 ? (goodSeconds / totalSeconds * 100) : 0.0;
    final trunkFails = setLoggers.fold<int>(
      0,
      (sum, logger) =>
          sum + ((logger.setLogs['trunk_fails_count'] as num?)?.toInt() ?? 0),
    );

    return [
      DetailCard(
        label: 'Giữ sạch',
        value: '${goodSeconds.toStringAsFixed(1)}s',
        subLabel: 'Mục tiêu ${totalSeconds.toStringAsFixed(0)}s',
        useRadial: true,
        radialValue: cleanRatio,
        color: cleanRatio >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Lỗi trục thân',
        value: '$trunkFails lần',
        subLabel: 'Võng hoặc chổng hông',
        color: trunkFails == 0 ? 'jade' : 'ruby',
      ),
    ];
  }
}
