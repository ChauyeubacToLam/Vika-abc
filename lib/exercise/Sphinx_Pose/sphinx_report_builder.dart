import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class SphinxReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['hip_seconds'],
        'shoulder_neck': ['straight_arm_seconds', 'shrug_neck_seconds'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'hip_seconds': (
          watch: 'Hông nhấc khỏi sàn làm mất mục tiêu mở nhẹ cột sống.',
          next: 'Ấn xương chậu xuống sàn trước khi nâng ngực.',
        ),
        'straight_arm_seconds': (
          watch: 'Duỗi thẳng tay biến Sphinx thành Cobra và tăng tải lưng.',
          next: 'Đặt khuỷu dưới vai, để cẳng tay đỡ lực.',
        ),
        'shrug_neck_seconds': (
          watch: 'Rụt vai hoặc ngửa cổ làm vùng gáy căng quá mức.',
          next: 'Hạ vai xa tai và nhìn chéo xuống thảm.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Hông': (c, t) => 'Hông giữ ổn định trong $c/$t giây.',
        'Tay': (c, t) => 'Tay đỡ lực tốt trong $c/$t giây.',
        'Cổ vai': (c, t) => 'Cổ vai thả lỏng trong $c/$t giây.',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'hip_seconds': 'Hông',
        'straight_arm_seconds': 'Tay',
        'shrug_neck_seconds': 'Cổ vai',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return [];

    final latestSet = setLoggers.last;
    final holdTime = latestSet.setLogs['active_hold_time'] as double? ?? 0.0;
    final stability = latestSet.setLogs['stability_score'] as double? ?? 0.0;

    final armSeconds =
        (latestSet.setLogs['straight_arm_seconds'] as num?)?.toDouble() ?? 0.0;
    final armAccuracy = (100.0 - (armSeconds * 20)).clamp(0.0, 100.0);

    return [
      DetailCard(
        label: 'Thời gian giữ',
        value: '${holdTime.toStringAsFixed(1)}s',
        subLabel: 'Hold Time',
        color: 'jade',
      ),
      DetailCard(
        label: 'Ổn định',
        value: stability.toStringAsFixed(0),
        subLabel: 'Điểm thăng bằng',
        color: 'amber',
        useRadial: true,
        radialValue: stability,
      ),
      DetailCard(
        label: 'Góc tay',
        value: '${armAccuracy.round()}%',
        subLabel: 'Độ chuẩn',
        color: 'jade',
        useRadial: true,
        radialValue: armAccuracy,
      ),
    ];
  }
}
