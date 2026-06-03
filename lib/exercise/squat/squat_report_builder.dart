import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/squat_interpreter.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

/// Squat-specific report builder.
/// Inherits buildReport() and generateCoachText() from base.
/// Only implements squat-specific analysis plus B4 praise/tip maps.

class SquatReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'ankle': ['heel_fails_count'],
        'lower_back': ['trunk_lean_fails_count'],
        'knee': ['depth_fails_count'],
        'hip': ['hip_shoulder_sync_fails_count', 'depth_fails_count'],
      };
  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'heel_fails_count': (
          watch: 'Trong bài Squat: Để ý gót chân hơn khi ngồi xuống.',
          next: 'Giữ trọng lượng dồn vào gót, đẩy đầu gối ra ngoài',
        ),
        'trunk_lean_fails_count': (
          watch: 'Trong bài Squat: Để ý lưng hơn khi ngồi xuống.',
          next: 'Mang lưng về phía sau khi ngồi xuống',
        ),
        'depth_fails_count': (
          watch: 'Trong bài Squat: Để ý độ sâu ở cuối rep.',
          next: 'Ngồi xuống sâu hơn nữa',
        ),
        'tempo_fails_count': (
          watch: 'Trong bài Squat: Để ý nhịp xuống và lên.',
          next: 'Kiểm soát chuyển động, giữ 2 giây trước khi lên',
        ),
        'hip_shoulder_sync_fails_count': (
          watch: 'Trong bài Squat: Để ý hông và vai đi cùng nhau.',
          next: 'Chỉ đầu gối chuyển động, hông vai phải giữ nguyên',
        ),
      };

  @override
  Set<String> criticalMetrics() => {
        'depth_fails_count',
        'trunk_lean_fails_count',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Độ sâu': (c, t) => 'Sâu chuẩn $c/$t rep - được đấy!',
        'Gót chân': (c, t) => 'Gót chân vững $c/$t rep - cổ chân khá ổn định!',
        'Lưng': (c, t) => 'Lưng thẳng $c/$t rep - rất tốt!',
        'Nhịp': (c, t) => 'Nhịp ổn định $c/$t rep - kiểm soát tốt!',
        'Đồng bộ hông-vai': (c, t) =>
            'Hông và vai đồng bộ $c/$t rep - rất chuẩn!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'depth_fails_count': 'Độ sâu',
        'heel_fails_count': 'Gót chân',
        'trunk_lean_fails_count': 'Lưng',
        'tempo_fails_count': 'Nhịp',
        'hip_shoulder_sync_fails_count': 'Đồng bộ hông-vai',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    // NOTE: Re-runs interpreter analysis. OK for 3-5 sets.
    // NOTE: Read from cached evidences when logger stores them.
    final questions = <DetectedEvidence>[];
    for (final setLogger in setLoggers) {
      final interpreter = SquatInterpreter(logger: setLogger);
      interpreter.analyze();
      questions.addAll(interpreter.evidences.expand((e) => e));
    }
    return questions.isNotEmpty ? questions.first : null;
  }
}
