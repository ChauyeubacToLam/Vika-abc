import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class HighPlankReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['sagging_fails_count'],
        'shoulder': ['piked_fails_count', 'elbow_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'sagging_fails_count': (
          watch:
              'Lỗi võng lưng rất nguy hiểm. Hãy tưởng tượng bạn đang rút rốn về phía cột sống.',
          next:
              'Lỗi võng lưng rất nguy hiểm. Hãy tưởng tượng bạn đang rút rốn về phía cột sống.',
        ),
        'piked_fails_count': (
          watch:
              'Chổng mông làm bài tập trở nên quá dễ và mất tác dụng vào cơ Core.',
          next:
              'Chổng mông làm bài tập trở nên quá dễ và mất tác dụng vào cơ Core.',
        ),
        'elbow_fails_count': (
          watch:
              'Đừng gập tay, xương cánh tay thẳng đứng sẽ giúp khóa khớp và tiết kiệm sức.',
          next:
              'Đừng gập tay, xương cánh tay thẳng đứng sẽ giúp khóa khớp và tiết kiệm sức.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Cột sống phẳng': (c, t) => 'Không một giây nào võng lưng - Tuyệt vời!',
        'Form chuẩn': (c, t) => 'Giữ form cực tĩnh, sức bền cơ lõi rất tốt!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'sagging_fails_count': 'Cột sống phẳng',
        'piked_fails_count': 'Form chuẩn',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return [];

    // Tính tổng thời gian perfect hold
    int totalPerfectTimeMs = setLoggers
        .map((l) => l.setLogs['total_perfect_time_ms'] as int? ?? 0)
        .reduce((a, b) => a + b);
    double perfectSeconds = totalPerfectTimeMs / 1000.0;

    // Tính Sagging Penalty (Số lần trigger lỗi võng lưng / giả định 1 lỗi làm mất 2s đánh giá)
    int sagFails = setLoggers
        .map((l) => l.setLogs['sagging_fails_count'] as int? ?? 0)
        .reduce((a, b) => a + b);

    // Độ ổn định Hông: Càng ít lỗi chổng/võng thì điểm càng cao
    int totalFails = sagFails +
        setLoggers
            .map((l) => l.setLogs['piked_fails_count'] as int? ?? 0)
            .reduce((a, b) => a + b);
    double stabilityScore = totalFails == 0
        ? 100
        : (100 - (totalFails * 5)).clamp(0, 100).toDouble();

    return [
      DetailCard(
        label: 'Thời gian Core chuẩn',
        value: '${perfectSeconds.toStringAsFixed(1)}s',
        subLabel: 'Mục tiêu: 30.0s',
        color: perfectSeconds >= 30 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Độ ổn định Hông',
        value: '${stabilityScore.toStringAsFixed(0)}%',
        subLabel: 'Không xê dịch',
        useRadial: true,
        radialValue: stabilityScore,
        color: stabilityScore > 80 ? 'jade' : 'ruby',
      ),
      DetailCard(
        label: 'Báo động Võng Lưng',
        value: '$sagFails lần',
        subLabel: 'Rủi ro thắt lưng',
        color: sagFails == 0 ? 'jade' : 'ruby',
      ),
    ];
  }
}
