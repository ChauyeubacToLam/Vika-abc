import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class SitUpReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['jerking_fails_count'],
        'hip': ['stability_fails_count'],
      };

  @override
  Map<String, String> faultToTipMap() => {
        'jerking_fails_count': 'Việc giật khi lên cong cột sống. Hãy chậm lại!',
        'stability_fails_count': 'Cơ hông đang làm việc thay cơ bụng. Hãy khóa chân chặt xuống thảm.',
        'rom_fails_count': 'Lên chưa đạt 90 độ sẽ không kích thích cơ tối đa.',
        'tempo_fails_count': 'Pha hạ thân người là lúc cơ bụng gồng nhiều nhất, đừng thả rơi tự do xuống sàn.',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Mượt mà': (c, t) => 'Lên xuống ổn định ở $c/$t rep!',
        'Cố định': (c, t) => 'Giữ chặt chân neo chuẩn $c/$t rep - Hoàn hảo!',
        'Kiểm soát': (c, t) => 'Hạ người có kiểm soát $c/$t rep!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'jerking_fails_count': 'Mượt mà',
        'stability_fails_count': 'Cố định',
        'tempo_fails_count': 'Kiểm soát',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) { 
    return null; 
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    if (totalReps == 0) return [];

    // FIXED: Thay ?[ bằng [ vì data của RepLog đã được xác định không null
    int romFails = allReps.where((r) => (r.data['fault_types'] as List? ?? []).contains('ROM')).length;
    double romCompleteness = totalReps > 0 ? ((totalReps - romFails) / totalReps) * 100 : 0;

    int jerkFails = allReps.where((r) => (r.data['fault_types'] as List? ?? []).contains('Jerking')).length;
    double movementControl = totalReps > 0 ? ((totalReps - jerkFails) / totalReps) * 100 : 0;

    final allTempos = allReps.map((r) => (r.data['lowering_time'] as num?)?.toDouble() ?? 0).where((t) => t > 0).toList();
    final avgTempo = allTempos.isEmpty ? 0.0 : allTempos.reduce((a, b) => a + b) / allTempos.length;

    return [
      DetailCard(
        label: 'Mượt (An toàn)',
        value: '${movementControl.toStringAsFixed(0)}%',
        subLabel: 'Không quăng người',
        useRadial: true,
        radialValue: movementControl,
        color: movementControl > 80 ? 'jade' : 'ruby',
      ),
      DetailCard(
        label: 'Full ROM',
        value: '${romCompleteness.toStringAsFixed(0)}%',
        subLabel: 'Lên đỉnh',
        useRadial: true,
        radialValue: romCompleteness,
        color: 'jade',
      ),
      DetailCard(
        label: 'Thời gian thả (Eccentric)',
        value: '${avgTempo.toStringAsFixed(1)}s',
        subLabel: 'Mục tiêu: >1.5s',
        color: 'amber',
      ),
    ];
  }
}