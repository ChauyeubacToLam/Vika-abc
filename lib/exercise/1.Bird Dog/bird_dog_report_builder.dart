import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class BirdDogReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['lumbar_fails_count', 'trunk_fails_count'],
        'shoulder_neck': ['alignment_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'lumbar_fails_count': (
          watch:
              'Trong Bird Dog: chân có xu hướng nâng quá cao làm lưng dưới mất trung tính.',
          next:
              'Nâng chân chỉ tới ngang thân người, siết bụng giữ lưng phẳng như mặt bàn.',
        ),
        'trunk_fails_count': (
          watch:
              'Trong Bird Dog: hông có xu hướng lắc khi tay và chân rời sàn.',
          next:
              'Mở rộng điểm tựa và siết hông, tưởng tượng giữ một ly nước trên lưng không để sánh.',
        ),
        'alignment_fails_count': (
          watch: 'Trong Bird Dog: cổ hoặc tay chân có lúc mất đường vươn dài.',
          next:
              'Vươn tay về trước và gót về sau như kéo dài cơ thể, giữ gáy dài và nhìn xuống sàn.',
        ),
        'tempo_fails_count': (
          watch: 'Kiểm soát: Giữ đủ 2s trên đỉnh.',
          next: 'Kiểm soát: Giữ đủ 2s trên đỉnh.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Lưng thẳng': (c, t) => 'Lưng giữ thẳng $c/$t rep - Cực an toàn!',
        'Ổn định': (c, t) => 'Cứng cáp $c/$t rep!',
        'Nhịp nhàng': (c, t) => 'Giữ form đủ 2s trong $c/$t rep!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'lumbar_fails_count': 'Lưng thẳng',
        'trunk_fails_count': 'Ổn định',
        'tempo_fails_count': 'Nhịp nhàng'
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    final totalGood = allReps.where((r) => r.correctForm).length;

    if (totalReps == 0) return [];

    final allTempos = allReps
        .map((r) => (r.data['hold_time'] as num?)?.toDouble() ?? 0)
        .where((t) => t > 0)
        .toList();
    final avgTempo = allTempos.isEmpty
        ? 0.0
        : allTempos.reduce((a, b) => a + b) / allTempos.length;

    int lumbarFails = setLoggers
        .map((l) => (l.setLogs['lumbar_fails_count'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a + b);
    double spineNeutrality =
        totalReps > 0 ? ((totalReps - lumbarFails) / totalReps) * 100 : 0;

    return [
      DetailCard(
        label: 'An toàn lưng',
        value: '${spineNeutrality.toStringAsFixed(0)}%',
        subLabel: 'Không võng lưng',
        useRadial: true,
        radialValue: spineNeutrality,
        color: 'jade',
      ),
      DetailCard(
        label: 'Thời gian Hold TB',
        value: '${avgTempo.toStringAsFixed(1)}s',
        subLabel: 'Mục tiêu: >2.0s',
        color: 'amber',
      ),
      DetailCard(
        label: 'Tổng Form',
        value: '${((totalGood / totalReps) * 100).toStringAsFixed(0)}%',
        subLabel: '$totalGood/$totalReps reps',
        useRadial: true,
        radialValue: (totalGood / totalReps) * 100,
        color: 'jade',
      ),
    ];
  }
}
