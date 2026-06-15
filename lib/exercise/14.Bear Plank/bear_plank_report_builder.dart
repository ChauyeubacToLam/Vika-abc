import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/interpreter/interpreter_base.dart';

class BearPlankReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, String> praiseMetricNames() => {
        'back_seconds': 'Lưng phẳng',
        'knee_seconds': 'Gối sát sàn',
        'weight_seconds': 'Vai trên cổ tay',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Lưng phẳng': (c, t) =>
            'Lưng giữ phẳng $c/$t giây - cột sống được bảo vệ tốt.',
        'Gối sát sàn': (c, t) =>
            'Gối hover sát sàn $c/$t giây - core gánh đúng phần việc.',
        'Vai trên cổ tay': (c, t) =>
            'Vai giữ trên cổ tay $c/$t giây - cổ tay nhẹ hơn nhiều.',
      };

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['back_seconds'],
        'wrist': ['weight_seconds'],
        'knee': ['knee_seconds'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'knee_seconds': (
          watch:
              'Trong Bear Plank: đầu gối có lúc nhấc cao hơn vùng hover mục tiêu.',
          next:
              'Khi nhấc gối cao quá 10cm, đùi trước sẽ gánh lực thay vì nhóm cơ Core. Hãy giữ gối sát mặt đất.',
        ),
        'back_seconds': (
          watch: 'Trong Bear Plank: lưng có lúc võng hoặc cong khi giữ hover.',
          next:
              'Võng lưng gây nén đĩa đệm thắt lưng. Hãy cuộn xương chậu và tưởng tượng bạn đang giữ một ly nước trên lưng.',
        ),
        'weight_seconds': (
          watch:
              'Trong Bear Plank: vai có xu hướng trôi quá xa về trước so với cổ tay.',
          next:
              'Lỗi rướn người về trước gây đau cổ tay. Vai phải luôn nằm trên một đường thẳng đứng với cổ tay.',
        ),
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return [];

    // ── Card 1: Thời gian giữ chuẩn (Perfect Hover Time) ────────────────────
    final totalHoverTimeMs = setLoggers.fold(
        0, (sum, l) => sum + (l.setLogs['total_hover_time_ms'] as int? ?? 0));
    final isTimeout =
        setLoggers.any((l) => l.setLogs['timeout_triggered'] == true);

    final totalSeconds = setLoggers.fold<double>(
      0,
      (sum, l) => sum + ((l.setLogs['total_seconds'] as num?)?.toDouble() ?? 0),
    );
    final kneeSeconds = setLoggers.fold<double>(
      0,
      (sum, l) => sum + ((l.setLogs['knee_seconds'] as num?)?.toDouble() ?? 0),
    );
    final weightSeconds = setLoggers.fold<double>(
      0,
      (sum, l) =>
          sum + ((l.setLogs['weight_seconds'] as num?)?.toDouble() ?? 0),
    );
    final kneeScore = totalSeconds > 0
        ? ((totalSeconds - kneeSeconds.clamp(0, totalSeconds)) /
                totalSeconds *
                100)
            .roundToDouble()
        : 100.0;
    final balanceScore = totalSeconds > 0
        ? ((totalSeconds - weightSeconds.clamp(0, totalSeconds)) /
                totalSeconds *
                100)
            .roundToDouble()
        : 100.0;

    return [
      // Card 1 — Thời gian giữ chuẩn
      DetailCard(
        label: 'Thời gian giữ chuẩn',
        value: '${(totalHoverTimeMs / 1000).toStringAsFixed(1)}s',
        subLabel: isTimeout
            ? 'Hết giờ (Timeout)'
            : 'Mục tiêu: ${BearPlankReportBuilder._targetSec}s',
        color: totalHoverTimeMs >= 30000 ? 'jade' : 'amber',
      ),
      // Card 2 — Chỉ số kiểm soát đầu gối
      DetailCard(
        label: 'Chỉ số kiểm soát đầu gối',
        value: '${kneeScore.toStringAsFixed(0)}%',
        subLabel: 'Gối sát mặt đất',
        useRadial: true,
        radialValue: kneeScore,
        color: kneeScore >= 80 ? 'jade' : (kneeScore >= 60 ? 'amber' : 'rose'),
      ),
      // Card 3 — Điểm cân bằng
      DetailCard(
        label: 'Điểm cân bằng',
        value: '${balanceScore.toStringAsFixed(0)}%',
        subLabel: 'Vai trên cổ tay',
        useRadial: true,
        radialValue: balanceScore,
        color: balanceScore >= 80
            ? 'jade'
            : (balanceScore >= 60 ? 'amber' : 'rose'),
      ),
    ];
  }

  static const int _targetSec = 30;
}
