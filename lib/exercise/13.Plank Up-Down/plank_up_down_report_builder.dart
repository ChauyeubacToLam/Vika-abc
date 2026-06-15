import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/interpreter/interpreter_base.dart';

class PlankUpDownReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_sagging_fails_count': 'Lưng vững',
        'hip_rotation_fails_count': 'Chống lắc hông',
        'arm_extension_fails_count': 'Duỗi tay',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Lưng vững': (c, t) => 'Lưng không võng $c/$t rep - cốt lõi rất chắc.',
        'Chống lắc hông': (c, t) =>
            'Hông giữ yên $c/$t rep - khung chậu cố định tốt.',
        'Duỗi tay': (c, t) =>
            'Tay duỗi thẳng $c/$t rep - lên High Plank dứt khoát.',
      };

  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['trunk_sagging_fails_count'],
        'shoulder_neck': [
          'arm_extension_fails_count',
          'hip_rotation_fails_count'
        ], // Xoay hông nhiều gây lực vặn lên vai
        'wrist': ['arm_extension_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'trunk_sagging_fails_count': (
          watch:
              'Trong Plank Up-Down: lưng dưới có xu hướng võng khi chuyển giữa khuỷu tay và bàn tay.',
          next:
              'Võng lưng cực kỳ nguy hiểm. Hãy siết chặt cơ bụng, cuộn xương chậu trước khi đẩy tay.',
        ),
        'hip_rotation_fails_count': (
          watch:
              'Trong Plank Up-Down: hông có xu hướng xoay qua lại khi đổi tay dẫn.',
          next:
              'Lắc hông làm mất tác dụng của Core. Mẹo: Mở rộng 2 chân hơn vai để tạo chân đế vững chắc.',
        ),
        'arm_extension_fails_count': (
          watch:
              'Trong Plank Up-Down: tay có lúc chưa duỗi thẳng khi lên High Plank.',
          next:
              'Bạn chưa duỗi thẳng tay ở pha High Plank, làm giảm hiệu quả lên cơ tay sau (Tricep).',
        ),
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

    // ── Card 1: Điểm ổn định cốt lõi ──────────────────────────────────────
    // % số rep KHÔNG bị sụt hông (trunk_sagging_fails)
    final saggingFails = setLoggers.fold(
        0,
        (sum, l) =>
            sum + (l.setLogs['trunk_sagging_fails_count'] as int? ?? 0));
    final coreScore =
        ((totalReps - saggingFails.clamp(0, totalReps)) / totalReps * 100)
            .roundToDouble();

    // ── Card 2: Độ cố định khung chậu ──────────────────────────────────────
    // Anti-Rotation Index: % số rep KHÔNG bị lắc hông (hip_rotation_fails)
    final hipFails = setLoggers.fold(0,
        (sum, l) => sum + (l.setLogs['hip_rotation_fails_count'] as int? ?? 0));
    final stabilityScore =
        ((totalReps - hipFails.clamp(0, totalReps)) / totalReps * 100)
            .roundToDouble();

    // ── Card 3: Tính đối xứng ────────────────────────────────────────────
    // Left/Right lead arm balance across all sets
    final totalLeftLead = setLoggers.fold(
        0, (sum, l) => sum + (l.setLogs['left_lead_count'] as int? ?? 0));
    final totalRightLead = setLoggers.fold(
        0, (sum, l) => sum + (l.setLogs['right_lead_count'] as int? ?? 0));
    final totalLeads = totalLeftLead + totalRightLead;
    final symmetryScore = totalLeads > 0
        ? (1.0 - (totalLeftLead - totalRightLead).abs() / totalLeads) * 100
        : 100.0;

    String symmetryLabel;
    if (totalLeads == 0) {
      symmetryLabel = 'Không có dữ liệu';
    } else {
      symmetryLabel = 'T: $totalLeftLead — P: $totalRightLead rep';
    }

    return [
      // Card 1 — Điểm ổn định cốt lõi
      DetailCard(
        label: 'Điểm ổn định cốt lõi',
        value: '${coreScore.toStringAsFixed(0)}%',
        subLabel: 'Rep không bị võng lưng',
        useRadial: true,
        radialValue: coreScore,
        color: coreScore >= 80 ? 'jade' : (coreScore >= 60 ? 'amber' : 'rose'),
      ),
      // Card 2 — Độ cố định khung chậu
      DetailCard(
        label: 'Độ cố định khung chậu',
        value: '${stabilityScore.toStringAsFixed(0)}%',
        subLabel: 'Rep không lắc hông',
        useRadial: true,
        radialValue: stabilityScore,
        color: stabilityScore >= 80
            ? 'jade'
            : (stabilityScore >= 60 ? 'amber' : 'rose'),
      ),
      // Card 3 — Tính đối xứng
      DetailCard(
        label: 'Tính đối xứng',
        value: '${symmetryScore.toStringAsFixed(0)}%',
        subLabel: symmetryLabel,
        useRadial: true,
        radialValue: symmetryScore,
        color: symmetryScore >= 80 ? 'jade' : 'amber',
      ),
    ];
  }
}
