import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class VUpReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['sync_fails_count', 'jerking_fails_count'],
        'hamstring': ['knee_fails_count'],
      };

  @override
  Map<String, String> faultToTipMap() => {
        'sync_fails_count':
            'Nâng tay lên trước sẽ tạo áp lực bẻ cong thắt lưng. Hãy tưởng tượng tay và chân bạn được nối bằng một sợi dây.',
        'jerking_fails_count':
            'Lực giật là kẻ thù của đĩa đệm. Hãy lên bằng sức căng của cơ bụng.',
        'rom_fails_count':
            'Bạn chưa gập thành hình chữ V. Cố ép bụng vào đùi sâu hơn nữa.',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Hiệp đồng': (c, t) => 'Đồng bộ tay chân $c/$t rep - Cực kỳ hoàn hảo!',
        'Biên độ': (c, t) => 'Chữ V cực gắt $c/$t rep!',
        'Trơn tru': (c, t) => 'Lên không một chút quán tính $c/$t rep!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'sync_fails_count': 'Hiệp đồng',
        'rom_fails_count': 'Biên độ',
        'jerking_fails_count': 'Trơn tru',
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

    // Tính điểm Đồng bộ (Sync)
    int syncFails = setLoggers
        .map((l) => l.setLogs['sync_fails_count'] as int? ?? 0)
        .reduce((a, b) => a + b);
    double syncScore =
        totalReps > 0 ? ((totalReps - syncFails) / totalReps) * 100 : 0;

    // V-Angle Completeness (% rep gập sâu)
    int romFails = setLoggers
        .map((l) => l.setLogs['rom_fails_count'] as int? ?? 0)
        .reduce((a, b) => a + b);
    double romCompleteness =
        totalReps > 0 ? ((totalReps - romFails) / totalReps) * 100 : 0;

    // Eccentric Tempo
    final allTempos = allReps
        .map((r) => (r.data['lowering_time'] as num?)?.toDouble() ?? 0)
        .where((t) => t > 0)
        .toList();
    final avgTempo = allTempos.isEmpty
        ? 0.0
        : allTempos.reduce((a, b) => a + b) / allTempos.length;

    return [
      DetailCard(
        label: 'Chỉ số đồng bộ (Sync)',
        value: '${syncScore.toStringAsFixed(0)}%',
        subLabel: 'Tay chân cùng lúc',
        useRadial: true,
        radialValue: syncScore,
        color: syncScore > 80 ? 'jade' : 'ruby',
      ),
      DetailCard(
        label: 'Độ gập chữ V',
        value: '${romCompleteness.toStringAsFixed(0)}%',
        subLabel: 'Ép sát ngực',
        useRadial: true,
        radialValue: romCompleteness,
        color: 'jade',
      ),
      DetailCard(
        label: 'Tốc độ nhả cơ',
        value: '${avgTempo.toStringAsFixed(1)}s',
        subLabel: 'Mục tiêu: >1.0s',
        color: avgTempo >= 1.0 ? 'jade' : 'amber',
      ),
    ];
  }
}
