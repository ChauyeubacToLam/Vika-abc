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
  Map<String, String> faultToTipMap() => {
        'heel_fails_count': 'Giữ trọng lượng dồn vào gót, đẩy đầu gối ra ngoài',
        'trunk_lean_fails_count': 'Mang lưng về phía sau khi ngồi xuống',
        'depth_fails_count': 'Ngồi xuống sâu hơn nữa',
        'tempo_fails_count': 'Kiểm soát chuyển động, giữ 2 giây trước khi lên',
        'hip_shoulder_sync_fails_count':
            'Chỉ đầu gối chuyển động, hông vai phải giữ nguyên',
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
    // TODO: Read from cached evidences when logger stores them.
    final questions = <DetectedEvidence>[];
    for (final setLogger in setLoggers) {
      final interpreter = SquatInterpreter(logger: setLogger);
      interpreter.analyze();
      questions.addAll(interpreter.evidences.expand((e) => e));
    }
    return questions.isNotEmpty ? questions.first : null;
  }

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;
    final totalGood = allReps.where((r) => r.correctForm).length;

    if (totalReps == 0) return [];

    // ── Card 1: Best depth ──
    final allDepths = allReps
        .map((r) => (r.data['peak_knee_angle'] as num?)?.toDouble())
        .where((d) => d != null && d > 0)
        .cast<double>()
        .toList();
    final bestDepth =
        allDepths.isEmpty ? 0.0 : allDepths.reduce((a, b) => a < b ? a : b);

    final setAvgDepths = setLoggers.map((l) {
      final ds = l.repLogs
          .map((r) => (r.data['peak_knee_angle'] as num?)?.toDouble())
          .where((d) => d != null && d > 0)
          .cast<double>()
          .toList();
      return ds.isEmpty ? 0.0 : ds.reduce((a, b) => a + b) / ds.length;
    }).toList();

    // ── Card 2: Average tempo ──
    final allTempos = allReps
        .map((r) => (r.data['descending_time'] as num?)?.toDouble())
        .where((t) => t != null && t > 0)
        .cast<double>()
        .toList();
    final avgTempo = allTempos.isEmpty
        ? 0.0
        : allTempos.reduce((a, b) => a + b) / allTempos.length;

    final setAvgTempos = setLoggers.map((l) {
      final ts = l.repLogs
          .map((r) => (r.data['descending_time'] as num?)?.toDouble())
          .where((t) => t != null && t > 0)
          .cast<double>()
          .toList();
      return ts.isEmpty ? 0.0 : ts.reduce((a, b) => a + b) / ts.length;
    }).toList();

    // ── Card 3: Accuracy radial ──
    final accuracy = (totalGood / totalReps * 100).roundToDouble();

    return [
      DetailCard(
        label: 'Depth tốt nhất',
        value: '${bestDepth.toStringAsFixed(0)}°',
        subLabel: 'TB per set',
        miniBarValues: setAvgDepths,
        miniBarMax: 110,
        lowerIsBetter: true,
        color: 'jade',
      ),
      DetailCard(
        label: 'Nhịp xuống TB',
        value: '${avgTempo.toStringAsFixed(1)}s',
        subLabel: 'TB per set',
        miniBarValues: setAvgTempos,
        miniBarMax: 3.0,
        color: 'amber',
      ),
      DetailCard(
        label: 'Độ chính xác',
        value: '${accuracy.round()}%',
        subLabel: '$totalGood/$totalReps rep',
        useRadial: true,
        radialValue: accuracy,
        color: 'jade',
      ),
    ];
  }
}
