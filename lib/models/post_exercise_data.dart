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
  final String insightIcon;
  final String insightText;
  final String? insightTip;

  const SetReportData({
    required this.setIndex,
    required this.score,
    required this.goodReps,
    required this.totalReps,
    required this.repResults,
    required this.insightIcon,
    required this.insightText,
    this.insightTip,
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
/// Subclasses implement 3 exercise-specific methods:
///   - pickInsight()
///   - detectIssue()
///   - buildDetailCards()
///
/// buildReport() and generateCoachText() are shared.
/// Override generateCoachText() only if an exercise needs
/// custom coach text logic.
abstract class ExerciseReportBuilder {
  // ── Subclasses MUST implement these 3 ──

  (String, String, String?) pickInsight(
    ExerciseLogger logger,
    ExerciseLogger? prevLogger,
    int setScore,
    int? prevScore,
  );

  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers);

  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers);

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
      final prevLogger = i > 0 ? setLoggers[i - 1] : null;

      final maxRep = (logger.setLogs["max_rep"] as num?)?.toInt() ?? 0;
      final goodReps = (logger.setLogs["good_rep_count"] as num?)?.toInt() ?? 0;
      final score = maxRep > 0 ? (goodReps / maxRep * 100).round() : 0;

      int? prevScore;
      if (prevLogger != null) {
        final prevMax = (prevLogger.setLogs["max_rep"] as num?)?.toInt() ?? 0;
        final prevGood =
            (prevLogger.setLogs["good_rep_count"] as num?)?.toInt() ?? 0;
        prevScore = prevMax > 0 ? (prevGood / prevMax * 100).round() : 0;
      }

      final repResults = logger.repLogs.map((r) => r.correctForm).toList();
      final (insIcon, insText, insTip) =
          pickInsight(logger, prevLogger, score, prevScore);

      sets.add(SetReportData(
        setIndex: i,
        score: score,
        goodReps: goodReps,
        totalReps: maxRep,
        repResults: repResults,
        insightIcon: insIcon,
        insightText: insText,
        insightTip: insTip,
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
