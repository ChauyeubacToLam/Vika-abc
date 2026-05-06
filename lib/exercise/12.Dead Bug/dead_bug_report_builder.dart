import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class DeadBugReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['anti_extension_fails_count'],
        'shoulder': ['stable_limbs_fails_count'],
      };

  @override
  Map<String, String> faultToTipMap() => {
        'anti_extension_fails_count': 'Lưng hở khỏi sàn là dấu hiệu cơ bụng đã ngừng làm việc. Hãy hít sâu và ép chặt thắt lưng xuống thảm.',
        'coordination_fails_count': 'Việc chuyển động cùng bên sẽ làm mất đi khả năng rèn luyện dây thần kinh cơ chéo của bài tập.',
        'stable_limbs_fails_count': 'Chỉ di chuyển 2 chi, 2 chi còn lại phải "đóng băng". Sự cô lập này là chìa khóa của sức mạnh cốt lõi.',
        'tempo_fails_count': 'Bạn đang tập luyện hệ thần kinh chứ không phải chạy đua. Càng chậm càng tốt.',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Khóa lưng': (c, t) => 'Không hề võng lưng $c/$t rep - Core thép!',
        'Não bộ': (c, t) => 'Phối hợp chéo chính xác $c/$t rep!',
        'Cô lập': (c, t) => 'Chi trụ bất động tuyệt đối $c/$t rep!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'anti_extension_fails_count': 'Khóa lưng',
        'coordination_fails_count': 'Não bộ',
        'stable_limbs_fails_count': 'Cô lập',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) { return null; }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    if (totalReps == 0) return [];

    // Điểm Anti-Extension Score (% không bị võng lưng)
    int antiExtFails = setLoggers.map((l) => l.setLogs['anti_extension_fails_count'] as int? ?? 0).reduce((a, b) => a + b);
    double antiExtScore = totalReps > 0 ? ((totalReps - antiExtFails) / totalReps) * 100 : 0;

    // Coordination Accuracy (% đi đúng chéo chi)
    int coordFails = setLoggers.map((l) => l.setLogs['coordination_fails_count'] as int? ?? 0).reduce((a, b) => a + b);
    double coordScore = totalReps > 0 ? ((totalReps - coordFails) / totalReps) * 100 : 0;

    // Tempo Control
    final allTempos = allReps.map((r) => (r.data['extending_time'] as num?)?.toDouble() ?? 0).where((t) => t > 0).toList();
    final avgTempo = allTempos.isEmpty ? 0.0 : allTempos.reduce((a, b) => a + b) / allTempos.length;

    return [
      DetailCard(
        label: 'Điểm khóa thắt lưng',
        value: '${antiExtScore.toStringAsFixed(0)}%',
        subLabel: 'Lưng sát sàn',
        useRadial: true,
        radialValue: antiExtScore,
        color: antiExtScore > 80 ? 'jade' : 'ruby',
      ),
      DetailCard(
        label: 'Độ nhạy thần kinh',
        value: '${coordScore.toStringAsFixed(0)}%',
        subLabel: 'Chéo chi chuẩn',
        useRadial: true,
        radialValue: coordScore,
        color: 'jade',
      ),
      DetailCard(
        label: 'Tốc độ hạ (Tempo)',
        value: '${avgTempo.toStringAsFixed(1)}s',
        subLabel: 'Mục tiêu: >1.5s',
        color: avgTempo >= 1.5 ? 'jade' : 'amber',
      ),
    ];
  }
}