import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class LegRaiseReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['pelvic_fails_count', 'tempo_fails_count'],
        'knee': ['knee_fails_count'],
      };

  @override
  Map<String, String> faultToTipMap() => {
        'pelvic_fails_count': 'Võng lưng báo hiệu hông bạn đã mỏi. Đừng ráng hạ chân sát mặt đất nếu lưng bạn bị hổng lên.',
        'tempo_fails_count': 'Lực kéo quán tính của chân rơi tự do sẽ giật mạnh vào cột sống thắt lưng. Hãy kìm chân lại.',
        'knee_fails_count': 'Cơ đùi sau (Hamstring) của bạn có vẻ bị căng cứng nên không thể duỗi thẳng. Tập giãn cơ thêm nhé.',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Khóa chậu': (c, t) => 'Không nhấp nhô hông $c/$t rep - Cột sống an toàn tuyệt đối!',
        'Nhả cơ': (c, t) => 'Kiểm soát nhịp độ thả chân xuất sắc $c/$t rep!',
        'Đôi chân': (c, t) => 'Duỗi thẳng gối hoàn hảo $c/$t rep!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'pelvic_fails_count': 'Khóa chậu',
        'tempo_fails_count': 'Nhả cơ',
        'knee_fails_count': 'Đôi chân',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) { return null; }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    if (totalReps == 0) return [];

    // Pelvic Control Index (% Không bị võng lưng)
    int pelvicFails = setLoggers.map((l) => l.setLogs['pelvic_fails_count'] as int? ?? 0).reduce((a, b) => a + b);
    double pelvicControl = totalReps > 0 ? ((totalReps - pelvicFails) / totalReps) * 100 : 0;

    // Eccentric Tempo
    final allTempos = allReps.map((r) => (r.data['lowering_time'] as num?)?.toDouble() ?? 0).where((t) => t > 0).toList();
    final avgTempo = allTempos.isEmpty ? 0.0 : allTempos.reduce((a, b) => a + b) / allTempos.length;

    // Leg Straightness
    int kneeFails = setLoggers.map((l) => l.setLogs['knee_fails_count'] as int? ?? 0).reduce((a, b) => a + b);
    double legStraightness = totalReps > 0 ? ((totalReps - kneeFails) / totalReps) * 100 : 0;

    return [
      DetailCard(
        label: 'Độ an toàn khung chậu',
        value: '${pelvicControl.toStringAsFixed(0)}%',
        subLabel: 'Lưng sát sàn',
        useRadial: true,
        radialValue: pelvicControl,
        color: pelvicControl > 80 ? 'jade' : 'ruby',
      ),
      DetailCard(
        label: 'Kiểm soát hạ chân',
        value: '${avgTempo.toStringAsFixed(1)}s',
        subLabel: 'Mục tiêu: >2.0s',
        color: avgTempo >= 2.0 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Độ dẻo chân (Straight)',
        value: '${legStraightness.toStringAsFixed(0)}%',
        subLabel: 'Không gập gối',
        useRadial: true,
        radialValue: legStraightness,
        color: 'jade',
      ),
    ];
  }
}