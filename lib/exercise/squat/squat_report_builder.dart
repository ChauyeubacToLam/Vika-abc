import 'package:vinafit_mobile/models/post_exercise_data.dart';
import 'package:vinafit_mobile/interpreter/squat_interpreter.dart';
import 'package:vinafit_mobile/interpreter/interpreter_base.dart';
import 'package:vinafit_mobile/utils/exercise_logger.dart';

class SquatReportBuilderConfig {
  static const double metricFailRatioThreshold = 0.2;
  static const double improvementRatioThreshold = 0.2;
  static const double badRepRatioThreshold = 0.5;

  static const List<({String key, String name, String tip, String declineTip})>
      metricPriority = [
    (
      key: 'trunk_lean_fails_count',
      name: 'lưng',
      tip: 'Giữ lưng thẳng, đẩy hông ra sau.',
      declineTip: 'Giữ lưng thẳng, đẩy hông ra sau.',
    ),
    (
      key: 'depth_fails_count',
      name: 'độ sâu',
      tip: 'Hạ hông thấp hơn, đùi song song sàn.',
      declineTip: 'Hạ hông thấp hơn, đùi song song sàn.',
    ),
    (
      key: 'heel_fails_count',
      name: 'gót chân',
      tip: 'Giữ trọng lượng dồn vào gót.',
      declineTip: 'Giữ trọng lượng dồn vào gót.',
    ),
    (
      key: 'hip_shoulder_sync_fails_count',
      name: 'đồng bộ hông-vai',
      tip: 'Giữ vai và hông di chuyển cùng nhau.',
      declineTip: 'Tránh để hông nâng lên quá sớm.',
    ),
  ];
}

/// Squat-specific report builder.
/// Inherits buildReport() and generateCoachText() from base.
/// Only implements the 3 exercise-specific methods.
class SquatReportBuilder extends ExerciseReportBuilder {
  @override
  (String, String, String?) pickInsight(
    dynamic logger,
    dynamic prevLogger,
    int setScore,
    int? prevScore,
  ) {
    if (logger is! ExerciseLogger) {
      return (
        '⚠️',
        'Không có dữ liệu set nào được ghi lại.',
        'Hoàn thành ít nhất 1 rep để nhận phân tích.',
      );
    }

    final previousLogger = prevLogger is ExerciseLogger ? prevLogger : null;

    final maxRep = (logger.setLogs["max_rep"] as num?)?.toInt() ?? 0;
    if (logger.repLogs.isEmpty || maxRep == 0) {
      return (
        '⚠️',
        'Không có rep nào được ghi lại.',
        'Hoàn thành ít nhất 1 rep để nhận phân tích.',
      );
    }

    final goodReps = (logger.setLogs["good_rep_count"] as num?)?.toInt() ?? 0;

    // ── 1. Perfect set ──
    if (goodReps == maxRep) {
      return (
        '✨',
        'Hoàn hảo! $maxRep/$maxRep rep đúng form.',
        'Tiếp tục giữ kỹ thuật này!',
      );
    }

    // ── 2. Improved vs previous set ──
    if (previousLogger != null && previousLogger.repLogs.isNotEmpty) {
      final result =
          _findMetricChange(logger, previousLogger, maxRep, improved: true);
      if (result != null) return result;
    }

    // ── 3. Metric faults above threshold ──
    for (final metric in SquatReportBuilderConfig.metricPriority) {
      final fails = (logger.setLogs[metric.key] as num?)?.toInt() ?? 0;
      if (fails / maxRep > SquatReportBuilderConfig.metricFailRatioThreshold) {
        return (
          '👁',
          'Lỗi ${metric.name}: $fails/$maxRep rep.',
          metric.tip,
        );
      }
    }

    // ── 4. Low overall score ──
    if (goodReps / maxRep < SquatReportBuilderConfig.badRepRatioThreshold) {
      return (
        '💪',
        'Chỉ $goodReps/$maxRep rep đúng form.',
        'Tập trung kỹ thuật, cải thiện từng chút!',
      );
    }

    // ── 5. Got worse vs previous set ──
    if (previousLogger != null && previousLogger.repLogs.isNotEmpty) {
      final result =
          _findMetricChange(logger, previousLogger, maxRep, improved: false);
      if (result != null) return result;
    }

    // ── 6. Default ──
    return (
      '📊',
      '$goodReps/$maxRep rep đúng form.',
      null,
    );
  }

  @override
  IssueQuestion? detectIssue(List<dynamic> setLoggers) {
    final typedLoggers = setLoggers.whereType<ExerciseLogger>().toList();

    // NOTE: Re-runs interpreter analysis. OK for 3-5 sets.
    // TODO: Read from cached evidences when logger stores them.
    final evidences = <DetectedEvidence>[];
    for (final setLogger in typedLoggers) {
      final interpreter = SquatInterpreter(logger: setLogger);
      interpreter.analyze();
      evidences.addAll(interpreter.evidences.expand((e) => e));
    }

    if (evidences.isEmpty) return null;
    final top = evidences.first;
    return IssueQuestion(
      observation: _issueObservation(top),
      question: top.question,
      key: top.issueId,
    );
  }

  @override
  List<DetailCard> buildDetailCards(List<dynamic> setLoggers) {
    final typedLoggers = setLoggers.whereType<ExerciseLogger>().toList();
    final allReps = typedLoggers.expand((l) => l.repLogs).toList();
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

    final setAvgDepths = typedLoggers.map((l) {
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

    final setAvgTempos = typedLoggers.map((l) {
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

  String _issueObservation(DetectedEvidence issue) => switch (issue.issueId) {
        'ankle_mobility' =>
          'AI thấy gót chân nhấc lên nhiều trong lúc squat.',
        'ankle_mobility_restriction' =>
          'AI thấy cổ chân và thân trên cùng mất ổn định khi xuống sâu.',
        'hip_flexor_overactivity' =>
          'AI thấy thân trên đổ về trước khá nhiều khi xuống squat.',
        'limited_mobility' =>
          'AI thấy độ sâu hiện tại vẫn còn bị giới hạn.',
        _ =>
          'AI ghi nhận tín hiệu: ${issue.rawSignal.replaceAll('_', ' ')}.',
      };

  // ── Private helper ──

  (String, String, String?)? _findMetricChange(
    ExerciseLogger logger,
    ExerciseLogger prevLogger,
    int maxRep, {
    required bool improved,
  }) {
    for (final metric in SquatReportBuilderConfig.metricPriority) {
      final prev = (prevLogger.setLogs[metric.key] as num?)?.toInt() ?? 0;
      final curr = (logger.setLogs[metric.key] as num?)?.toInt() ?? 0;
      final denominator = prev.toDouble() + 1;

      if (improved) {
        final ratio = (prev - curr) / denominator;
        if (ratio > SquatReportBuilderConfig.improvementRatioThreshold) {
          return (
            '📈',
            'Lỗi ${metric.name} giảm: $prev → $curr rep.',
            metric.tip,
          );
        }
      } else {
        final ratio = (curr - prev) / denominator;
        if (ratio > SquatReportBuilderConfig.improvementRatioThreshold) {
          return (
            '📉',
            'Lỗi ${metric.name} tăng: $prev → $curr rep.',
            metric.declineTip,
          );
        }
      }
    }

    final prevGood =
        (prevLogger.setLogs["good_rep_count"] as num?)?.toInt() ?? 0;
    final currGood = (logger.setLogs["good_rep_count"] as num?)?.toInt() ?? 0;
    final denominator = prevGood.toDouble() + 1;

    if (improved) {
      if ((currGood - prevGood) / denominator >
          SquatReportBuilderConfig.improvementRatioThreshold) {
        return (
          '📈',
          'Rep đúng tăng: $prevGood → $currGood.',
          'Tiếp tục giữ phong độ!',
        );
      }
    } else {
      if ((prevGood - currGood) / denominator >
          SquatReportBuilderConfig.improvementRatioThreshold) {
        return (
          '📉',
          'Rep đúng giảm: $prevGood → $currGood.',
          'Bình thường khi mệt. Tập trung set sau!',
        );
      }
    }

    return null;
  }
}
