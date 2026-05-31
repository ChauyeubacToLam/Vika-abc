import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

class MountainClimberReportBuilder extends ExerciseReportBuilder {
  // ---------------------------------------------------------------------------
  // Pain → Fault mapping
  // ---------------------------------------------------------------------------

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['trunk_fails_count'], // Võng lưng dồn lực lên cột sống
        'shoulder': ['trunk_fails_count'], // Mất ổn định trục thân
        'wrist': ['trunk_fails_count'],
      };

  // ---------------------------------------------------------------------------
  // Fault → Tip
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> faultToTipMap() => {
        'trunk_fails_count':
            'Siết chặt cơ bụng, cuộn xương cụt nhẹ xuống để khóa form lưng thẳng.',
        'rom_fails_count':
            'Cố gắng kéo gối cao ngang rốn hoặc sát khuỷu tay để đốt mỡ hiệu quả hơn.',
      };

  // ---------------------------------------------------------------------------
  // Praise
  // ---------------------------------------------------------------------------

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Core': (c, t) => 'Giữ form cực đỉnh $c/$t rep!',
        'ROM': (c, t) => 'Biên độ sâu $c/$t rep, rất ăn bụng!',
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_fails_count': 'Core',
        'rom_fails_count': 'ROM',
      };

  // ---------------------------------------------------------------------------
  // Detail Cards
  // ---------------------------------------------------------------------------

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    final totalReps = allReps.length;

    if (totalReps == 0) return [];

    final totalGood = allReps.where((r) => r.correctForm).length;
    final accuracy = (totalGood / totalReps * 100).roundToDouble();

    // --- Core Stability Score ---
    // Lấy từ core_stability_ratio thực tế (% frame hông ổn định), đã được
    // TrunkStabilityMetric track chính xác hơn so với cách tính gián tiếp cũ.
    // Fix: wrap (double.tryParse(...) ?? 1.0) để ?? chỉ áp dụng cho tryParse,
    // không phải cho toàn bộ biểu thức sum + ...
    final double avgCoreRatio = setLoggers.fold<double>(
          0.0,
          (sum, log) =>
              sum +
              (double.tryParse(
                      log.setLogs['core_stability_ratio']?.toString() ??
                          '1.0') ??
                  1.0),
        ) /
        setLoggers.length;
    final double coreScore = (avgCoreRatio * 100).clamp(0.0, 100.0);

    // --- ROM Score ---
    final int totalGoodRom = setLoggers.fold(
        0, (s, l) => s + (l.setLogs['rom_good_count'] as int? ?? 0));
    final int totalShortRom = setLoggers.fold(
        0, (s, l) => s + (l.setLogs['rom_short_count'] as int? ?? 0));
    final int totalRomReps = totalGoodRom + totalShortRom;
    final double romScore = totalRomReps == 0
        ? 100.0
        : (totalGoodRom / totalRomReps * 100).clamp(0.0, 100.0);

    // --- Pace: reps/phút ---
    final double totalMinutes = setLoggers.fold<double>(
      0.0,
      (sum, log) => sum + (log.setLogs['duration_ms'] as int? ?? 0) / 60000.0,
    );
    final String paceLabel = totalMinutes > 0
        ? '${(totalReps / totalMinutes).round()} rep/phút'
        : '-';

    return [
      DetailCard(
        label: 'Độ Ổn Định Core',
        value: '${coreScore.round()}%',
        subLabel: 'Không võng lưng',
        useRadial: true,
        radialValue: coreScore,
        color: 'amber',
      ),
      DetailCard(
        label: 'Biên Độ Co Gối',
        value: '${romScore.round()}%',
        subLabel: '$totalGoodRom/$totalRomReps rep đạt chuẩn',
        useRadial: true,
        radialValue: romScore,
        color: 'jade',
      ),
      DetailCard(
        label: 'Tỷ Lệ Chính Xác',
        value: '${accuracy.round()}%',
        subLabel: '$totalGood/$totalReps rep',
        useRadial: true,
        radialValue: accuracy,
        color: 'blue',
      ),
      DetailCard(
        label: 'Nhịp Độ',
        value: paceLabel,
        subLabel: 'Tốc độ trung bình',
        color: 'purple',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Interpreter
  // ---------------------------------------------------------------------------

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    // NOTE: Điền đúng các field theo constructor DetectedEvidence của project:
    //   issueId, confidence, exerciseSource, rawSignal, question
    //
    // Logic muốn implement: nếu trunk_fails > 50% số set → gợi ý tập Plank
    //
    //   final int failingSets = setLoggers
    //       .where((l) => (l.setLogs['trunk_fails_count'] as int? ?? 0) > 0)
    //       .length;
    //   if (setLoggers.isNotEmpty && failingSets / setLoggers.length >= 0.5) {
    //     return DetectedEvidence(
    //       issueId: 'core_weakness',
    //       confidence: failingSets / setLoggers.length,
    //       exerciseSource: exerciseName,
    //       rawSignal: 'trunk_fails_count',
    //       question: 'Bạn có thường bị đau lưng sau khi tập không?',
    //     );
    //   }
    return null;
  }
}
