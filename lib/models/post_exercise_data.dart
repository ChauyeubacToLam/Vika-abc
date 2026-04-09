/// Generic data contract for all post-exercise UI screens.
///
/// The UI screens (RestScreen, SplashScreen, ExecutiveSummaryPage) consume
/// ONLY this data. They never import exercise-specific classes.
///
/// Each exercise implements [ExerciseReportBuilder] to produce this data
/// from its own RepLogs and setLogs.
///
/// Usage:
///   final builder = SquatReportBuilder(); // or GluteBridgeReportBuilder, etc.
///   final report = builder.buildReport(
///     setLoggers: _setLoggers,
///     exerciseName: 'Squat',
///     metValue: 5.0,
///   );
///   // Pass report.sets[i] to RestScreen
///   // Pass report to ExecutiveSummaryPage
library;

// ═══════════════════════════════════════════════════════════════
// CORE DATA CLASSES
// ═══════════════════════════════════════════════════════════════

/// Top-level report for an entire exercise session (all sets).
class PostExerciseData {
  final String exerciseName;
  final double metValue; // for calorie calc: MET * weightKg * hours

  /// Per-set data, in order. sets[0] = first set.
  final List<SetReportData> sets;

  // ── Executive summary data ──
  final int formScore; // 0-100, across all sets
  final String coachText; // template-generated, no API call
  final IssueQuestion? issueQuestion; // null = no issues detected
  final List<DetailCard> detailCards; // exercise-specific detail cards

  const PostExerciseData({
    required this.exerciseName,
    required this.metValue,
    required this.sets,
    required this.formScore,
    required this.coachText,
    this.issueQuestion,
    required this.detailCards,
  });

  /// Total reps across all sets.
  int get totalReps => sets.fold(0, (sum, s) => sum + s.totalReps);

  /// Total good reps across all sets.
  int get totalGoodReps => sets.fold(0, (sum, s) => sum + s.goodReps);

  /// Per-set scores for the set comparison bars.
  List<int> get setScores => sets.map((s) => s.score).toList();

  /// Whether form improved from first to last set.
  bool get improved => sets.length >= 2 && sets.last.score >= sets.first.score;
}

/// Data for a single set — drives the rest screen between sets.
class SetReportData {
  final int setIndex; // 0-based
  final int score; // 0-100
  final int goodReps;
  final int totalReps;

  /// Per-rep results: true = good form, false = bad form.
  /// Length = totalReps. Drives the chunky rep bars.
  final List<bool> repResults;

  // ── Fatigue detection (camera-triggered) ──
  final bool fatigueDetected;
  final String? fatigueText; // e.g. "Nhịp chậm lại + depth nông hơn cuối set"
  final String? fatigueQuestion; // e.g. "Bạn có thấy mệt hơn không?"

  // ── Data-driven insight (always present) ──
  final String insightIcon; // "📈", "👁", "✨", "📊"
  final String insightText; // "Rep 3, 5: lưng nghiêng — còn lại tốt"
  final String? insightTip; // "Giữ ngực cao set sau"

  const SetReportData({
    required this.setIndex,
    required this.score,
    required this.goodReps,
    required this.totalReps,
    required this.repResults,
    this.fatigueDetected = false,
    this.fatigueText,
    this.fatigueQuestion,
    required this.insightIcon,
    required this.insightText,
    this.insightTip,
  });
}

/// Camera-informed issue question for the executive summary.
class IssueQuestion {
  final String observation; // "Gót chân nâng ở 3/5 rep set đầu"
  final String question; // "Bạn có cảm thấy căng ở mắt cá?"
  final String key; // "ankle_mobility" — for ML logging

  const IssueQuestion({
    required this.observation,
    required this.question,
    required this.key,
  });
}

/// A detail card for the collapsible detail section.
class DetailCard {
  final String label; // "Depth tốt nhất"
  final String value; // "74°"
  final String? subLabel; // "TB per set"

  /// Per-set values for the mini bar chart inside the card.
  /// null = no mini chart (just show the number).
  final List<double>? miniBarValues;

  /// Max value for normalizing mini bars. If null, uses max of miniBarValues.
  final double? miniBarMax;

  /// Whether higher values are better (true) or lower (true for depth angles).
  final bool lowerIsBetter;

  /// Color key: "jade", "coral", "amber", or a hex string.
  final String color;

  /// If true, show a radial ring instead of mini bars.
  final bool useRadial;

  /// For radial: the percentage (0-100).
  final double? radialValue;

  const DetailCard({
    required this.label,
    required this.value,
    this.subLabel,
    this.miniBarValues,
    this.miniBarMax,
    this.lowerIsBetter = false,
    this.color = 'jade',
    this.useRadial = false,
    this.radialValue,
  });
}

// ═══════════════════════════════════════════════════════════════
// BUILDER INTERFACE
// ═══════════════════════════════════════════════════════════════

/// Abstract interface that each exercise implements.
///
/// The exercise class knows its own RepLog keys, thresholds, and
/// how to detect fatigue/issues. It produces a generic [PostExerciseData]
/// that the UI consumes without knowing what exercise it's showing.
abstract class ExerciseReportBuilder {
  /// Build the complete post-exercise report from logged data.
  ///
  /// [setLoggers] — one ExerciseLogger per set, in order.
  /// [exerciseName] — display name (e.g. "Squat", "Glute Bridge").
  /// [metValue] — MET value for calorie estimation.
  PostExerciseData buildReport({
    required List<dynamic> setLoggers, // List<ExerciseLogger>
    required String exerciseName,
    required double metValue,
  }) {
    final sets = <SetReportData>[];

    for (var i = 0; i < setLoggers.length; i++) {
      final logger = setLoggers[i];
      final prevLogger = i > 0 ? setLoggers[i - 1] : null;

      final repLogs = _tryReadRepLogs(logger);
      final repResults = repLogs.map((rep) => _tryReadCorrectForm(rep)).toList();

      final maxRep = _tryReadIntFromSetLogs(logger, 'max_rep') ?? repResults.length;
      final totalReps = maxRep > 0 ? maxRep : repResults.length;
      final inferredGood = repResults.where((ok) => ok).length;
      final loggedGood = _tryReadIntFromSetLogs(logger, 'good_rep_count') ?? inferredGood;
      final goodReps = loggedGood.clamp(0, totalReps);

      final score = totalReps > 0 ? ((goodReps / totalReps) * 100).round() : 0;
      final prevScore = sets.isNotEmpty ? sets.last.score : null;

      final fatigue = detectFatigue(logger);
      final insight = pickInsight(logger, prevLogger, score, prevScore);

      sets.add(
        SetReportData(
          setIndex: i,
          score: score,
          goodReps: goodReps,
          totalReps: totalReps,
          repResults: repResults,
          fatigueDetected: fatigue.$1,
          fatigueText: fatigue.$2,
          fatigueQuestion: fatigue.$3,
          insightIcon: insight.$1,
          insightText: insight.$2,
          insightTip: insight.$3,
        ),
      );
    }

    final setScores = sets.map((set) => set.score).toList();
    final avgScore =
        setScores.isEmpty ? 0 : (setScores.reduce((a, b) => a + b) / setScores.length).round();
    final improved = sets.length >= 2 && sets.last.score >= sets.first.score;

    return PostExerciseData(
      exerciseName: exerciseName,
      metValue: metValue,
      sets: sets,
      formScore: avgScore,
      coachText: generateCoachText(setScores, improved),
      issueQuestion: detectIssue(setLoggers),
      detailCards: buildDetailCards(setLoggers),
    );
  }

  // ── Helpers that subclasses implement ──

  /// Detect fatigue from per-rep data within a single set.
  /// Returns (detected, text, question) or (false, null, null).
  (bool, String?, String?) detectFatigue(dynamic logger) =>
      (false, null, null);

  /// Pick the best insight for a set, given optional previous set.
  /// Returns (icon, text, tip?).
  (String, String, String?) pickInsight(
    dynamic logger,
    dynamic prevLogger,
    int setScore,
    int? prevScore,
  );

  /// Detect the single most important issue across all sets.
  /// Returns null if no issues detected.
  IssueQuestion? detectIssue(List<dynamic> setLoggers);

  /// Generate the template-based coach text (no API call).
  String generateCoachText(List<int> setScores, bool improved) {
    if (setScores.isEmpty) {
      return 'Buổi tập đã hoàn tất. Tiếp tục duy trì đều đặn để cải thiện form.';
    }

    final avg = setScores.reduce((a, b) => a + b) / setScores.length;
    final latest = setScores.last;

    if (latest >= 85) {
      return 'Form rất ổn định. Tiếp tục duy trì nhịp hiện tại ở các buổi sau.';
    }
    if (improved) {
      return 'Form đã cải thiện qua các set. Giữ nhịp này để tiến bộ nhanh hơn.';
    }
    if (avg < 50) {
      return 'Kỹ thuật chưa ổn định. Giảm tốc độ và ưu tiên kiểm soát động tác.';
    }
    return 'Buổi tập ổn định. Tập trung thêm vào kỹ thuật để nâng độ chính xác.';
  }

  /// Build exercise-specific detail cards.
  List<DetailCard> buildDetailCards(List<dynamic> setLoggers);

  List<dynamic> _tryReadRepLogs(dynamic logger) {
    try {
      final logs = logger.repLogs;
      return logs is List ? logs : const [];
    } catch (_) {
      return const [];
    }
  }

  bool _tryReadCorrectForm(dynamic repLog) {
    try {
      return repLog.correctForm == true;
    } catch (_) {
      return false;
    }
  }

  int? _tryReadIntFromSetLogs(dynamic logger, String key) {
    try {
      final setLogs = logger.setLogs;
      if (setLogs is! Map) return null;
      final value = setLogs[key];
      if (value is num) return value.toInt();
      return null;
    } catch (_) {
      return null;
    }
  }
}
