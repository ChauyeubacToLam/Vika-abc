import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class WarriorOneReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['trunk_lean_seconds', 'back_straight_seconds'],
        'shoulder_neck': ['cervical_seconds', 'arm_seconds'],
        'knee': ['back_knee_seconds'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'trunk_lean_seconds': (
          watch: 'Thân người ngả quá nhiều sẽ làm mất điểm tựa của tư thế.',
          next:
              'Ấn bàn chân sau xuống sàn và kéo thân người cao lên trước khi giữ.',
        ),
        'cervical_seconds': (
          watch: 'Cổ ngửa hoặc rụt quá lâu làm tư thế căng lên vùng gáy.',
          next: 'Nhìn thẳng theo thân người, giữ gáy dài và mềm.',
        ),
        'arm_seconds': (
          watch: 'Tay không vươn ổn định làm ngực và vai khó mở.',
          next:
              'Vươn tay lên cao vừa sức, giữ khuỷu tay mềm nhưng không rơi về trước.',
        ),
        'back_knee_seconds': (
          watch: 'Gối sau gập nhiều làm mất đường kéo dài của chân sau.',
          next: 'Đẩy gót sau ra xa và giữ chân sau dài hơn.',
        ),
        'back_straight_seconds': (
          watch: 'Thân sau không ổn định khiến hông xoay và lưng dễ bù trừ.',
          next: 'Thu nhẹ xương sườn, giữ hông nhìn về trước trong lúc giữ.',
        ),
      };

  @override
  Set<String> criticalMetrics() => {
        'trunk_lean_seconds',
        'back_straight_seconds',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_lean_seconds': 'Trục thân',
        'cervical_seconds': 'Cổ vai',
        'arm_seconds': 'Tay',
        'back_knee_seconds': 'Chân sau',
        'back_straight_seconds': 'Hông lưng',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Trục thân': (c, t) => 'Trục thân ổn định trong $c/$t giây.',
        'Cổ vai': (c, t) => 'Cổ vai giữ gọn trong $c/$t giây.',
        'Tay': (c, t) => 'Tay vươn ổn định trong $c/$t giây.',
        'Chân sau': (c, t) => 'Chân sau giữ dài trong $c/$t giây.',
        'Hông lưng': (c, t) => 'Hông lưng kiểm soát tốt trong $c/$t giây.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    if (setLoggers.isEmpty) return const [];

    final totalSeconds = _sumDouble(setLoggers, 'total_seconds');
    final goodSeconds = _sumDouble(setLoggers, 'good_seconds');
    final cleanRatio =
        totalSeconds > 0 ? (goodSeconds / totalSeconds * 100) : 0.0;
    final trunkSeconds = _sumDouble(setLoggers, 'trunk_lean_seconds');
    final stanceSeconds = _sumDouble(setLoggers, 'back_knee_seconds') +
        _sumDouble(setLoggers, 'back_straight_seconds');

    return [
      DetailCard(
        label: 'Giữ sạch',
        value: '${goodSeconds.toStringAsFixed(1)}s',
        subLabel: 'Mục tiêu ${totalSeconds.toStringAsFixed(0)}s',
        useRadial: true,
        radialValue: cleanRatio,
        color: cleanRatio >= 80 ? 'jade' : 'amber',
      ),
      DetailCard(
        label: 'Lỗi trục thân',
        value: '${trunkSeconds.toStringAsFixed(1)}s',
        subLabel: 'Ngả người hoặc mất trục',
        color: trunkSeconds == 0 ? 'jade' : 'ruby',
      ),
      DetailCard(
        label: 'Chân sau',
        value: '${stanceSeconds.toStringAsFixed(1)}s',
        subLabel: 'Gối sau và hông lưng',
        color: stanceSeconds == 0 ? 'jade' : 'amber',
      ),
    ];
  }

  double _sumDouble(List<ExerciseLogger> setLoggers, String key) {
    return setLoggers.fold<double>(
      0,
      (sum, logger) => sum + ((logger.setLogs[key] as num?)?.toDouble() ?? 0.0),
    );
  }
}
