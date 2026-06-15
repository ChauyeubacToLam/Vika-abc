import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'butterfly_stretch.dart'; // Import để dùng ButterflyConfig.TARGET_HOLD_SECONDS

class ButterflyReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'hip': ['knee_seconds', 'foot_placement_seconds'],
        'lower_back': ['posture_seconds'],
        'knee': ['knee_seconds'],
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'knee_seconds': 'Mở gối',
        'posture_seconds': 'Lưng thẳng',
        'foot_placement_seconds': 'Vị trí chân',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'knee_seconds': (
          watch: 'Trong Butterfly: hai gối chưa mở đều hoặc còn cao.',
          next: 'Thả lỏng để hai gối rơi đều về phía sàn, đừng ép bằng tay.',
        ),
        'posture_seconds': (
          watch: 'Trong Butterfly: lưng có lúc bị gù xuống.',
          next: 'Ngồi cao như có sợi dây kéo đỉnh đầu lên, mở ngực.',
        ),
        'foot_placement_seconds': (
          watch: 'Trong Butterfly: gót chân để hơi xa hông.',
          next: 'Kéo hai gót chân lại gần hông để tăng độ giãn ở háng.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Mở gối': (c, t) =>
            'Hai gối mở đều xuống sàn - háng linh hoạt hơn rồi!',
        'Lưng thẳng': (c, t) => 'Lưng giữ thẳng suốt bài - tư thế rất đẹp!',
        'Vị trí chân': (c, t) => 'Gót chân đặt sát hông - độ giãn đạt tối đa!',
      };

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return [];

    final latestLog = setLoggers.last.setLogs;
    final totalHold = (latestLog["total_hold_time"] as num?)?.toDouble() ?? 0.0;
    final maxSep =
        (latestLog["max_knee_separation"] as num?)?.toDouble() ?? 0.0;

    return [
      DetailCard(
        label: 'Độ mở gối tối đa',
        value: maxSep.toStringAsFixed(0),
        subLabel: 'Biên độ tốt nhất',
        miniBarValues: const [],
        miniBarMax: 200,
        lowerIsBetter: false,
        color: 'jade',
      ),
      DetailCard(
        label: 'Thời gian Hold',
        value: '${totalHold.toStringAsFixed(0)}s',
        subLabel: 'Tổng thời gian kéo giãn',
        useRadial: true,
        // Dùng constant thay magic number — nếu target thay đổi thì cập nhật 1 chỗ duy nhất
        radialValue: (totalHold / ButterflyConfig.TARGET_HOLD_SECONDS * 100)
            .clamp(0, 100)
            .toDouble(),
        color: 'amber',
      ),
    ];
  }

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }
}
