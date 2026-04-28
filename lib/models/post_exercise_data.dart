/// Generic data contract for all post-exercise UI screens.
///
/// UI screens (RestScreen, SplashScreen, ExecutiveSummaryPage) consume
/// ONLY this data. They never import exercise-specific classes.
library;

import '../utils/exercise_logger.dart';
import '../interpreter/interpreter_base.dart';
import '../services/session_persistence.dart';

// ═══════════════════════════════════════════════════════════════
// CORE DATA CLASSES
// ═══════════════════════════════════════════════════════════════

class PostExerciseData {
  final String exerciseName;
  final double metValue;
  final List<SetReportData> sets;
  final int formScore;
  final String coachText;
  final DetectedEvidence? issueQuestion;
  final List<DetailCard> detailCards;

  const PostExerciseData({
    required this.exerciseName,
    required this.metValue,
    required this.sets,
    required this.formScore,
    required this.coachText,
    this.issueQuestion,
    required this.detailCards,
  });

  int get totalReps => sets.fold(0, (sum, s) => sum + s.totalReps);
  int get totalGoodReps => sets.fold(0, (sum, s) => sum + s.goodReps);
  List<int> get setScores => sets.map((s) => s.score).toList();
}

class SetReportData {
  final int setIndex;
  final int score;
  final int goodReps;
  final int totalReps;
  final List<bool> repResults;
  final String? praiseSentence;
  final String? coachTip;

  const SetReportData({
    required this.setIndex,
    required this.score,
    required this.goodReps,
    required this.totalReps,
    required this.repResults,
    this.praiseSentence,
    this.coachTip,
  });
}

class DetailCard {
  final String label;
  final String value;
  final String? subLabel;
  final List<double>? miniBarValues;
  final double? miniBarMax;
  final bool lowerIsBetter;
  final String color;
  final bool useRadial;
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
// BUILDER BASE CLASS
// ═══════════════════════════════════════════════════════════════

/// Base class for exercise report builders.
///
/// Subclasses implement 2 exercise-specific methods + 4 maps:
///   - detectIssue()
///   - buildDetailCards()
///   - praiseMetricNames()
///   - faultToTipMap()
///   - praiseSentenceMap()
///   - painToFaultMap()  (B7 — optional, defaults to {})
///
/// buildReport(), generateCoachText(), buildPraiseSentence(),
/// and buildCoachTip() are shared across all exercises.
abstract class ExerciseReportBuilder {
  // ── Subclasses MUST implement these 2 ──

  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers);

  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers);

  // ── Subclasses override these maps ──

  /// B7: Maps user pain area IDs to fault count keys this exercise tracks.
  /// Empty default for exercises without relevant pain mappings.
  Map<String, List<String>> painToFaultMap() => {};

  /// Maps fault count keys in setLogs to display labels.
  /// E.g. {'depth_fails_count': 'Độ sâu', 'heel_fails_count': 'Gót chân'}
  /// Values are FAIL counts: high number = bad.
  Map<String, String> praiseMetricNames() => {};

  /// Maps fault count keys to forward-looking coaching tips.
  /// Tips use external cueing (B3): "push the floor" not "extend your knees".
  Map<String, String> faultToTipMap() => {};

  /// Maps metric labels to Vietnamese praise sentence templates.
  /// Labels must match values in praiseMetricNames().
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {};

  // ── Praise priority ladder (shared, do not override) ──

  /// Threshold above which a metric is considered "habitually clean" and
  /// should be skipped in the generic metric tier to prevent repeat praise.
  static const double _habitualStrengthThreshold = 0.7;

  /// Number of past sessions to scan for habitual-strength detection.
  static const int _habitualStrengthWindow = 3;

  /// Percentage of reps clean in current set to qualify as a "win" for
  /// pain-linked or historically-weak metric tiers.
  static const double _metricWinThreshold = 0.7;

  /// Build a praise sentence for this set using a priority ladder.
  ///
  /// Walks tiers in order. First match wins. Returns null if nothing
  /// triggers — rest screen will hide the praise line.
  ///
  /// Tier 0: Perfect set (100% clean)
  /// Tier 1: Closed the coaching loop from previous set
  /// Tier 2: Pain-linked metric win (>70% clean this set)
  /// Tier 3: Historically weak metric improved (<50% clean in past, >70% now)
  /// Tier 4: Set-over-set improvement (score +10 or more vs previous set)
  /// Tier 5: Generic metric win, excluding habitual strengths
  /// null:   Nothing notable — skip the praise line
  String? buildPraiseSentence(
    ExerciseLogger logger, {
    required int setIndex,
    ExerciseLogger? previousSetLogger,
    int? previousSetIndex,
    String? previousSetCoachTip,
    List<PreviousSessionSummary> history = const [],
    List<String> userPainAreas = const [],
  }) {
    final totalReps = (logger.setLogs['max_rep'] as num?)?.toInt() ?? 0;
    final goodReps = (logger.setLogs['good_rep_count'] as num?)?.toInt() ?? 0;
    if (totalReps == 0) return null;

    // ─── Tier 0: Perfect set ───
    if (goodReps == totalReps) {
      return 'Hoàn hảo! Tất cả $totalReps rep đúng form.';
    }

    final metrics = praiseMetricNames();
    final painFaultKeys = _painFaultKeys(userPainAreas);

    // ─── Tier 1: Closed the coaching loop ───
    if (previousSetLogger != null && previousSetCoachTip != null) {
      final closedKey = _closedCoachingLoop(
        previousSetLogger: previousSetLogger,
        previousSetCoachTip: previousSetCoachTip,
        currentLogger: logger,
      );
      if (closedKey != null) {
        final label = metrics[closedKey] ?? closedKey;
        return 'Set trước bị lỗi $label, set này đã cải thiện rõ.';
      }
    }

    // ─── Tier 2: Pain-linked metric win ───
    for (final faultKey in painFaultKeys) {
      if (!metrics.containsKey(faultKey)) continue;
      final ratio = _cleanRatio(logger, faultKey, totalReps);
      if (ratio >= _metricWinThreshold) {
        final label = metrics[faultKey]!;
        return '$label hôm nay tốt — vùng bạn đang tập trung.';
      }
    }

    // ─── Tier 3: Historically weak metric improved ───
    if (history.isNotEmpty) {
      for (final faultKey in metrics.keys) {
        if (!_wasHistoricallyWeak(faultKey, history)) continue;
        final currentRatio = _cleanRatio(logger, faultKey, totalReps);
        if (currentRatio >= _metricWinThreshold) {
          final label = metrics[faultKey]!;
          return '$label hôm nay tốt hơn hẳn mọi khi.';
        }
      }
    }

    // ─── Tier 4: Set-over-set improvement ───
    if (previousSetLogger != null && previousSetIndex != null) {
      final improved = _setOverSetImprovement(previousSetLogger, logger);
      if (improved) {
        return 'Set ${setIndex + 1} tốt hơn set ${previousSetIndex + 1} rõ rệt.';
      }
    }

    // tier 4.5: Correct rep count > 60% of max rep count
    final ratio = goodReps / totalReps;
    if (ratio >= 0.65) {
      return '$goodReps/$totalReps rep đúng form — tốt đấy.';
    }

    // ─── Tier 5: Generic metric win (filtered) ───
    return _genericMetricPraise(
      logger: logger,
      totalReps: totalReps,
      history: history,
    );
  }

  /// Returns the forward-looking tip for the highest-count fault.
  /// Returns null if no faults (perfect set).
  String? buildCoachTip(ExerciseLogger logger) {
    final tipMap = faultToTipMap();
    if (tipMap.isEmpty) return null;

    String? worstKey;
    int worstCount = 0;

    for (final key in tipMap.keys) {
      final count = (logger.setLogs[key] as num?)?.toInt() ?? 0;
      if (count > worstCount) {
        worstCount = count;
        worstKey = key;
      }
    }

    if (worstKey == null || worstCount == 0) return null;
    return tipMap[worstKey];
  }

  // ── Helpers for praise ladder ──

  Set<String> _painFaultKeys(List<String> userPainAreas) {
    final keys = <String>{};
    final map = painToFaultMap();
    for (final pain in userPainAreas) {
      keys.addAll(map[pain] ?? const []);
    }
    return keys;
  }

  /// Ratio of clean reps in this set for the given fault key.
  /// 0.0 = every rep had the fault, 1.0 = no rep had it.
  double _cleanRatio(ExerciseLogger logger, String faultKey, int totalReps) {
    if (totalReps == 0) return 0;
    final fails = (logger.setLogs[faultKey] as num?)?.toInt() ?? 0;
    return (totalReps - fails) / totalReps;
  }

  /// Did the previous set's coach tip correspond to a fault that dropped
  /// in the current set? If yes, returns the fault key. Else null.
  String? _closedCoachingLoop({
    required ExerciseLogger previousSetLogger,
    required String previousSetCoachTip,
    required ExerciseLogger currentLogger,
  }) {
    // Reverse-lookup: which fault key produced this tip?
    final tipMap = faultToTipMap();
    String? matchingFaultKey;
    for (final entry in tipMap.entries) {
      if (entry.value == previousSetCoachTip) {
        matchingFaultKey = entry.key;
        break;
      }
    }
    if (matchingFaultKey == null) return null;

    final previousCount =
        (previousSetLogger.setLogs[matchingFaultKey] as num?)?.toInt() ?? 0;
    final currentCount =
        (currentLogger.setLogs[matchingFaultKey] as num?)?.toInt() ?? 0;

    // Previous set had the fault, current set has fewer — loop closed.
    if (previousCount > 0 && currentCount < previousCount) {
      return matchingFaultKey;
    }
    return null;
  }

  /// Metric is historically weak if clean ratio across last N sessions
  /// is below 50%.
  bool _wasHistoricallyWeak(
    String faultKey,
    List<PreviousSessionSummary> history,
  ) {
    final window = history.length >= _habitualStrengthWindow
        ? history.sublist(history.length - _habitualStrengthWindow)
        : history;
    if (window.isEmpty) return false;

    int totalReps = 0;
    int totalFails = 0;
    for (final session in window) {
      totalReps += session.totalReps;
      totalFails += session.faultCounts[faultKey] ?? 0;
    }
    if (totalReps == 0) return false;

    final cleanRatio = (totalReps - totalFails) / totalReps;
    return cleanRatio < 0.5;
  }

  /// Metric is a habitual strength if clean ratio across last N sessions
  /// is at or above [_habitualStrengthThreshold].
  bool _isHabitualStrength(
    String faultKey,
    List<PreviousSessionSummary> history,
  ) {
    final window = history.length >= _habitualStrengthWindow
        ? history.sublist(history.length - _habitualStrengthWindow)
        : history;
    if (window.isEmpty) return false;

    int totalReps = 0;
    int totalFails = 0;
    for (final session in window) {
      totalReps += session.totalReps;
      totalFails += session.faultCounts[faultKey] ?? 0;
    }
    if (totalReps == 0) return false;

    final cleanRatio = (totalReps - totalFails) / totalReps;
    return cleanRatio >= _habitualStrengthThreshold;
  }

  /// Returns true if current set score is at least 10 points higher than
  /// previous set score. Triggers the set-over-set praise tier.
  bool _setOverSetImprovement(
    ExerciseLogger previousSet,
    ExerciseLogger currentSet,
  ) {
    final previousMax = (previousSet.setLogs['max_rep'] as num?)?.toInt() ?? 0;
    final previousGood =
        (previousSet.setLogs['good_rep_count'] as num?)?.toInt() ?? 0;
    final currentMax = (currentSet.setLogs['max_rep'] as num?)?.toInt() ?? 0;
    final currentGood =
        (currentSet.setLogs['good_rep_count'] as num?)?.toInt() ?? 0;

    if (previousMax == 0 || currentMax == 0) return false;

    final previousScore = (previousGood / previousMax * 100).round();
    final currentScore = (currentGood / currentMax * 100).round();

    return currentScore >= previousScore + 10;
  }

  /// Tier 5: generic metric-first praise with habitual-strength filter.
  ///
  /// Walks praiseMetricNames() in order, finds highest clean ratio > 50%,
  /// BUT skips metrics that are clean in ≥70% of reps across the last 3
  /// sessions (habitual strengths produce hollow repeat praise).
  ///
  /// Returns null if all candidates are filtered out — rest screen hides
  /// the praise line.
  String? _genericMetricPraise({
    required ExerciseLogger logger,
    required int totalReps,
    required List<PreviousSessionSummary> history,
  }) {
    final metrics = praiseMetricNames();
    if (metrics.isEmpty) return null;

    String? bestLabel;
    String? bestKey;
    int bestGood = -1;
    double bestRatio = -1;

    for (final entry in metrics.entries) {
      final faultKey = entry.key;

      // Skip habitual strengths — prevents depth-always-praised failure mode.
      if (_isHabitualStrength(faultKey, history)) continue;

      final fails = (logger.setLogs[faultKey] as num?)?.toInt() ?? 0;
      final good = totalReps - fails;
      final ratio = good / totalReps;

      if (ratio > 0.5 && ratio > bestRatio) {
        bestRatio = ratio;
        bestGood = good;
        bestLabel = entry.value;
        bestKey = faultKey;
      }
    }

    if (bestLabel == null || bestKey == null || bestGood < 0) {
      // Everything was a habitual strength or nothing passed 50%.
      // Return null — rest screen hides praise line.
      return 'Xong set này rồi, tốt lắm.';
    }

    final template = praiseSentenceMap()[bestLabel];
    if (template != null) {
      return template(bestGood, totalReps);
    }

    return '$bestLabel đạt $bestGood/$totalReps rep — tốt lắm.';
  }

  // ── Coach text (shared, override only if needed) ──

  String generateCoachText(List<int> setScores) {
    if (setScores.isEmpty) return 'Hoàn thành buổi tập!';
    if (setScores.length == 1) {
      return setScores[0] >= 80
          ? 'Form tốt! ${setScores[0]}%.'
          : 'Hoàn thành buổi tập!';
    }

    final scoreStr = setScores.join('→');

    int ups = 0;
    int downs = 0;
    for (int i = 1; i < setScores.length; i++) {
      if (setScores[i] > setScores[i - 1]) {
        ups++;
      } else if (setScores[i] < setScores[i - 1]) {
        downs++;
      }
    }

    final netUp = setScores.last > setScores.first;
    final netDown = setScores.last < setScores.first;
    final improving = ups > downs && downs <= 1 && netUp;
    final declining = downs > ups && ups <= 1 && netDown;

    if (improving) {
      return setScores.last >= 80
          ? 'Cải thiện rõ rệt ($scoreStr%). Rất tốt!'
          : 'Đang tiến bộ ($scoreStr%). Tiếp tục!';
    }
    if (declining) {
      return 'Form giảm dần ($scoreStr%). Bình thường khi mệt. Thử giảm rep buổi sau.';
    }
    return 'Form ổn định ($scoreStr%). Buổi tập chắc chắn.';
  }

  // ── Report builder (entry point) ──

  PostExerciseData buildReport({
    required List<ExerciseLogger> setLoggers,
    required String exerciseName,
    required double metValue,
    List<PreviousSessionSummary> history = const [],
    List<String> userPainAreas = const [],
  }) {
    final sets = <SetReportData>[];

    for (int i = 0; i < setLoggers.length; i++) {
      final logger = setLoggers[i];
      final previousSetLogger = i > 0 ? setLoggers[i - 1] : null;
      final previousSetCoachTip =
          previousSetLogger != null ? buildCoachTip(previousSetLogger) : null;

      final maxRep = (logger.setLogs["max_rep"] as num?)?.toInt() ?? 0;
      final goodReps = (logger.setLogs["good_rep_count"] as num?)?.toInt() ?? 0;
      final score = maxRep > 0 ? (goodReps / maxRep * 100).round() : 0;

      final repResults = logger.repLogs.map((r) => r.correctForm).toList();

      sets.add(SetReportData(
        setIndex: i,
        score: score,
        goodReps: goodReps,
        totalReps: maxRep,
        repResults: repResults,
        praiseSentence: buildPraiseSentence(
          logger,
          setIndex: i,
          previousSetLogger: previousSetLogger,
          previousSetIndex: i > 0 ? i - 1 : null,
          previousSetCoachTip: previousSetCoachTip,
          history: history,
          userPainAreas: userPainAreas,
        ),
        coachTip: buildCoachTip(logger),
      ));
    }

    final setScores = sets.map((s) => s.score).toList();
    final totalReps = sets.fold<int>(0, (sum, s) => sum + s.totalReps);
    final totalGood = sets.fold<int>(0, (sum, s) => sum + s.goodReps);
    final formScore = totalReps > 0 ? (totalGood / totalReps * 100).round() : 0;

    return PostExerciseData(
      exerciseName: exerciseName,
      metValue: metValue,
      sets: sets,
      formScore: formScore,
      coachText: generateCoachText(setScores),
      issueQuestion: detectIssue(setLoggers),
      detailCards: buildDetailCards(setLoggers),
    );
  }
}
