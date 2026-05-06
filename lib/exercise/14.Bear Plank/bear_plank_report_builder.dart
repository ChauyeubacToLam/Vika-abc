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

    // Bài này log theo set, lấy data từ l.setLogs (Set-Level)
    final totalHoverTimeMs = setLoggers.fold(0, (sum, l) => sum + (l.setLogs['total_hover_time_ms'] as int? ?? 0));
    final isTimeout = setLoggers.any((l) => l.setLogs['timeout_triggered'] == true);
    
    // Tính các chỉ số phạt (Phạt dựa trên số frame bị lỗi)
    final kneeFails = setLoggers.fold(0, (sum, l) => sum + (l.setLogs['knee_fails'] as int? ?? 0));
    final weightFails = setLoggers.fold(0, (sum, l) => sum + (l.setLogs['weight_fails'] as int? ?? 0));

    // Knee Control Index (Càng ít fail gối -> Điểm càng cao)
    double kneeScore = 100 - (kneeFails * 0.5); 
    if (kneeScore < 0) kneeScore = 0;

    // Balance Score (Lỗi chúi vai)
    double balanceScore = 100 - (weightFails * 0.5);
    if (balanceScore < 0) balanceScore = 0;

    return [
      DetailCard(
        label: 'Thời gian giữ form',
        value: '${(totalHoverTimeMs / 1000).toStringAsFixed(1)}s',
        subLabel: isTimeout ? 'Hết giờ (Timeout)' : 'Hoàn thành',
        color: totalHoverTimeMs >= 30000 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Chỉ số kiểm soát Gối',
        value: '${kneeScore.toStringAsFixed(0)}%',
        subLabel: 'Tránh chổng mông',
        useRadial: true,
        radialValue: kneeScore,
        color: kneeScore > 80 ? 'jade' : 'rose',
      ),
      DetailCard(
        label: 'Cân bằng cổ tay',
        value: '${balanceScore.toStringAsFixed(0)}/100',
        subLabel: 'Trọng tâm tay - chân',
        color: 'blue',
      ),
    ];
  }
}