import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class HighPlankReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['sagging_seconds'],
        'shoulder_neck': ['piked_seconds', 'elbow_seconds'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'sagging_seconds': (
          watch: 'Trong High Plank: hông có lúc hạ xuống làm lưng dưới võng.',
          next:
              'Lỗi võng lưng rất nguy hiểm. Hãy tưởng tượng bạn đang rút rốn về phía cột sống.',
        ),
        'piked_seconds': (
          watch:
              'Trong High Plank: hông có lúc đẩy lên cao hơn đường thân người.',
          next:
              'Chổng mông làm bài tập trở nên quá dễ và mất tác dụng vào cơ Core.',
        ),
        'elbow_seconds': (
          watch: 'Trong High Plank: khuỷu tay có lúc gập khi đang chống giữ.',
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
        'sagging_seconds': 'Cột sống phẳng',
        'piked_seconds': 'Form chuẩn',
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

    final sagSeconds = setLoggers
        .map((l) => (l.setLogs['sagging_seconds'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a + b);

    // Độ ổn định Hông: Càng ít lỗi chổng/võng thì điểm càng cao
    final totalFaultSeconds = sagSeconds +
        setLoggers
            .map((l) => (l.setLogs['piked_seconds'] as num?)?.toDouble() ?? 0.0)
            .reduce((a, b) => a + b);
    double stabilityScore = totalFaultSeconds == 0
        ? 100
        : (100 - (totalFaultSeconds * 5)).clamp(0, 100).toDouble();

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
        value: '${sagSeconds.toStringAsFixed(1)}s',
        subLabel: 'Rủi ro thắt lưng',
        color: sagSeconds == 0 ? 'jade' : 'ruby',
      ),
    ];
  }
}
