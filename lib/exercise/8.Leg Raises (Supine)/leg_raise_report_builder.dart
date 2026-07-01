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
  Map<String, FaultTipCopy> faultToTipMap() => {
        'pelvic_fails_count': (
          watch: 'Trong Leg Raise: lưng dưới có lúc hở khỏi sàn khi hạ chân.',
          next:
              'Võng lưng báo hiệu hông bạn đã mỏi. Đừng ráng hạ chân sát mặt đất nếu lưng bạn bị hổng lên.',
        ),
        'tempo_fails_count': (
          watch:
              'Trong Leg Raise: chân có lúc hạ xuống quá nhanh ở pha đi xuống.',
          next:
              'Lực kéo quán tính của chân rơi tự do sẽ giật mạnh vào cột sống thắt lưng. Hãy kìm chân lại.',
        ),
        'rom_fails_count': (
          watch:
              'Chân có lúc chưa đi hết biên độ, nên bụng dưới chưa nhận đủ lực kiểm soát.',
          next:
              'Kéo gót chân đi theo một cung dài và nâng chân rõ ràng trước khi hạ xuống.',
        ),
        'knee_fails_count': (
          watch: 'Trong Leg Raise: gối có lúc gập khi chân đang nâng hoặc hạ.',
          next:
              'Cơ đùi sau (Hamstring) của bạn có vẻ bị căng cứng nên không thể duỗi thẳng. Tập giãn cơ thêm nhé.',
        ),
        'arm_position_fails_count': (
          watch:
              'Tay rời khỏi sàn làm thân người mất điểm neo, chân sẽ dễ kéo lưng theo.',
          next:
              'Ấn nhẹ hai tay xuống thảm như neo cơ thể lại, rồi để chân di chuyển chậm.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Khóa chậu': (c, t) =>
            'Không nhấp nhô hông $c/$t rep - Cột sống an toàn tuyệt đối!',
        'Nhả cơ': (c, t) => 'Kiểm soát nhịp độ thả chân xuất sắc $c/$t rep!',
        'Biên độ nâng': (c, t) =>
            'Biên độ nâng rõ $c/$t rep - bụng dưới làm việc tốt.',
        'Đôi chân': (c, t) => 'Duỗi thẳng gối hoàn hảo $c/$t rep!',
        'Tay neo sàn': (c, t) =>
            'Hai tay neo sàn ổn định $c/$t rep - thân người rất chắc.',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'pelvic_fails_count': 'Khóa chậu',
        'tempo_fails_count': 'Nhả cơ',
        'rom_fails_count': 'Biên độ nâng',
        'knee_fails_count': 'Đôi chân',
        'arm_position_fails_count': 'Tay neo sàn',
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

    // Pelvic Control Index (% Không bị võng lưng)
    int pelvicFails = setLoggers
        .map((l) => l.setLogs['pelvic_fails_count'] as int? ?? 0)
        .reduce((a, b) => a + b);
    double pelvicControl =
        totalReps > 0 ? ((totalReps - pelvicFails) / totalReps) * 100 : 0;

    // Eccentric Tempo
    final allTempos = allReps
        .map((r) => (r.data['lowering_time'] as num?)?.toDouble() ?? 0)
        .where((t) => t > 0)
        .toList();
    final avgTempo = allTempos.isEmpty
        ? 0.0
        : allTempos.reduce((a, b) => a + b) / allTempos.length;

    // Leg Straightness
    int kneeFails = setLoggers
        .map((l) => l.setLogs['knee_fails_count'] as int? ?? 0)
        .reduce((a, b) => a + b);
    double legStraightness =
        totalReps > 0 ? ((totalReps - kneeFails) / totalReps) * 100 : 0;

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
