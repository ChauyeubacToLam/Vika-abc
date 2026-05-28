import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/interpreter/interpreter_base.dart';

class BearPlankReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
    'lower_back': ['back_fails'],
    'wrist': ['weight_fails'],
    'knee': ['knee_fails'],
  };

  @override
  Map<String, String> faultToTipMap() => {
    'knee_fails': 'Khi nhấc gối cao quá 10cm, đùi trước sẽ gánh lực thay vì nhóm cơ Core. Hãy giữ gối sát mặt đất.',
    'back_fails': 'Võng lưng gây nén đĩa đệm thắt lưng. Hãy cuộn xương chậu và tưởng tượng bạn đang giữ một ly nước trên lưng.',
    'weight_fails': 'Lỗi rướn người về trước gây đau cổ tay. Vai phải luôn nằm trên một đường thẳng đứng với cổ tay.',
  };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) { return null; }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return [];

    // ── Card 1: Thời gian giữ chuẩn (Perfect Hover Time) ────────────────────
    final totalHoverTimeMs = setLoggers.fold(0, (sum, l) => sum + (l.setLogs['total_hover_time_ms'] as int? ?? 0));
    final isTimeout = setLoggers.any((l) => l.setLogs['timeout_triggered'] == true);

    // ── Card 2: Chỉ số kiểm soát đầu gối (Knee Control Index) ──────────────
    // % số frame hovering KHÔNG bị fault đầu gối
    final totalHoverFrames = setLoggers.fold(0, (sum, l) => sum + (l.setLogs['total_hover_frames'] as int? ?? 0));
    final kneeFaultFrames = setLoggers.fold(0, (sum, l) => sum + (l.setLogs['knee_fault_frames'] as int? ?? 0));
    final kneeScore = totalHoverFrames > 0
        ? ((totalHoverFrames - kneeFaultFrames.clamp(0, totalHoverFrames)) / totalHoverFrames * 100).roundToDouble()
        : 100.0;

    // ── Card 3: Điểm cân bằng (Balance Score) ───────────────────────────────
    // % số frame hovering KHÔNG bị chúi vai
    final weightFaultFrames = setLoggers.fold(0, (sum, l) => sum + (l.setLogs['weight_fault_frames'] as int? ?? 0));
    final balanceScore = totalHoverFrames > 0
        ? ((totalHoverFrames - weightFaultFrames.clamp(0, totalHoverFrames)) / totalHoverFrames * 100).roundToDouble()
        : 100.0;

    return [
      // Card 1 — Thời gian giữ chuẩn
      DetailCard(
        label: 'Thời gian giữ chuẩn',
        value: '${(totalHoverTimeMs / 1000).toStringAsFixed(1)}s',
        subLabel: isTimeout ? 'Hết giờ (Timeout)' : 'Mục tiêu: ${BearPlankReportBuilder._targetSec}s',
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
        color: balanceScore >= 80 ? 'jade' : (balanceScore >= 60 ? 'amber' : 'rose'),
      ),
    ];
  }

  static const int _targetSec = 30;
}