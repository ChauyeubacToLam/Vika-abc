/// Generic data contract for all post-exercise UI screens.
///
/// UI screens (RestScreen, SplashScreen, ExecutiveSummaryPage) consume
/// ONLY this data. They never import exercise-specific classes.
library;

import '../utils/exercise_logger.dart';
import '../interpreter/interpreter_base.dart';

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
  final String? praiseSentence; // B4: "Sâu chuẩn 8/10 rep — đẹp lắm!"
  final String? coachTip; // B4: "Đẩy sàn ra xa khi đứng lên"

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
/// Subclasses implement 2 exercise-specific methods + 3 B4 maps:
///   - detectIssue()
///   - buildDetailCards()
///   - praiseMetricNames()   ← B4: which metrics can be praised
///   - faultToTipMap()       ← B4: fault → coaching tip
///   - praiseSentenceMap()   ← B4: metric label → Vietnamese sentence
///
/// buildReport(), generateCoachText(), buildPraiseSentence(),
/// and buildCoachTip() are shared.
abstract class ExerciseReportBuilder {
  // ── Subclasses MUST implement these 2 ──

  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers);

  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers);

  // ── B4: Subclasses override these 3 maps ──

  /// Maps fault count keys in setLogs to display labels.
  /// E.g. {'depth_fails_count': 'Depth', 'heel_fails_count': 'Gót chân'}
  /// Values are FAIL counts: high number = bad.
  Map<String, String> praiseMetricNames() => {};

  /// Maps fault count keys to forward-looking coaching tips.
  /// Tips use external cueing (B3): "push the floor" not "extend your knees".
  Map<String, String> faultToTipMap() => {};

  /// Maps metric labels to Vietnamese praise sentence templates.
  /// Labels must match values in praiseMetricNames().
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {};

  // ── B4: Shared praise + coaching logic ──

  /// Finds the best-performing metric and generates a praise sentence.
  /// "Best" = fewest fails relative to total reps.
  /// Only praises metrics where >50% of reps were good.
  String? buildPraiseSentence(ExerciseLogger logger) {
    final totalReps = (logger.setLogs['max_rep'] as num?)?.toInt() ?? 0;
    final goodReps = (logger.setLogs['good_rep_count'] as num?)?.toInt() ?? 0;
    if (totalReps == 0) return null;

    // Perfect set
    if (goodReps == totalReps) {
      return 'Hoàn hảo! Tất cả $totalReps rep đúng form! 🎯';
    }

    // No reps correct at all
    if (goodReps == 0) {
      return 'Hoàn thành $totalReps rep! Set sau sẽ tốt hơn.';
    }

    // Find the metric with the FEWEST fails (= best performance)
    final metrics = praiseMetricNames();
    String? bestLabel;
    int bestGood = -1;
    double bestRatio = -1;

    for (final entry in metrics.entries) {
      final fails = (logger.setLogs[entry.key] as num?)?.toInt() ?? 0;
      final good = totalReps - fails;
      final ratio = good / totalReps;

      // Only praise if more than half were good
      if (ratio > 0.5 && ratio > bestRatio) {
        bestRatio = ratio;
        bestGood = good;
        bestLabel = entry.value;
      }
    }

    // No metric passed 50% threshold
    if (bestLabel == null || bestGood < 0) {
      return 'Hoàn thành $totalReps rep! Set sau sẽ tốt hơn.';
    }

    // Look up sentence template
    final template = praiseSentenceMap()[bestLabel];
    if (template != null) {
      return template(bestGood, totalReps);
    }

    // Generic fallback
    return '$bestLabel đạt $bestGood/$totalReps rep — tốt lắm!';
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

  // ── Shared: override only if needed ──

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

  // ── Fully shared: no override needed ──

  PostExerciseData buildReport({
    required List<ExerciseLogger> setLoggers,
    required String exerciseName,
    required double metValue,
  }) {
    final sets = <SetReportData>[];

    for (int i = 0; i < setLoggers.length; i++) {
      final logger = setLoggers[i];

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
        praiseSentence: buildPraiseSentence(logger),
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
