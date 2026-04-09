import '../models/post_exercise_data.dart';
import '../utils/exercise_logger.dart';
import '../interpreter/interpreter_base.dart';
import 'squat/squat_report_builder.dart';

// ═══════════════════════════════════════════════════════════════
// REGISTRY
// ═══════════════════════════════════════════════════════════════

/// When adding a new exercise:
/// 1. Create FooReportBuilder extending ExerciseReportBuilder
/// 2. Implement pickInsight(), detectIssue(), buildDetailCards()
/// 3. Add entry here
/// 4. Done — buildReport(), generateCoachText() inherited from base
final Map<String, ({ExerciseReportBuilder builder, double met})>
    reportBuilders = {
  'squat': (builder: SquatReportBuilder(), met: 5.0),
  'squat_assessment': (builder: SquatReportBuilder(), met: 5.0),
  // 'glute_bridge': (builder: GluteBridgeReportBuilder(), met: 3.5),
  // 'wall_push_up': (builder: WallPushUpReportBuilder(), met: 3.0),
};

// ═══════════════════════════════════════════════════════════════
// INTEGRATION GUIDE
// ═══════════════════════════════════════════════════════════════

/*
  In exercise_experience_screen.dart:

  import '../../models/post_exercise_data.dart';
  import '../../exercise/report_builder_registry.dart';

  // Fields:
  PostExerciseData? _fullReport;
  SetReportData? _currentSetReport;

  // ── Set complete (active → rest): ──

  void _handleSetComplete(ExerciseLogger logger) {
    _setLoggers.add(logger);

    if (_isAssessment) {
      Navigator.of(context).pop({'logger': logger});
      return;
    }

    final entry = reportBuilders[widget.definition.id];
    if (entry != null) {
      final report = entry.builder.buildReport(
        setLoggers: _setLoggers,
        exerciseName: widget.definition.name,
        metValue: entry.met,
      );
      _currentSetReport = report.sets.last;
    }

    setState(() => _phase = _WorkoutFlowPhase.summary);
  }

  // ── All sets complete (rest → executive): ──

  void _handleSummaryNext() {
    if (_currentSet >= _spec.sets) {
      final entry = reportBuilders[widget.definition.id];
      _fullReport = entry?.builder.buildReport(
        setLoggers: _setLoggers,
        exerciseName: widget.definition.name,
        metValue: entry!.met,
      );
      setState(() => _phase = _WorkoutFlowPhase.executive);
      return;
    }
    _currentSet += 1;
    _startSet();
  }

  // ── Fatigue (set-level score drop → ask more rest): ──

  bool _shouldAskFatigueQuestion() {
    if (_setLoggers.length < 2) return false;
    final entry = reportBuilders[widget.definition.id];
    if (entry == null) return false;
    final report = entry.builder.buildReport(
      setLoggers: _setLoggers,
      exerciseName: widget.definition.name,
      metValue: entry.met,
    );
    final scores = report.setScores;
    return scores.length >= 2 &&
        scores.last < scores[scores.length - 2] - 15;
  }
  // If true → rest screen shows:
  //   "Form giảm so với set trước. Nghỉ thêm 15s không?"
  //   Có → timer 60s. Không → timer 45s.

  // ── UI screens: ──

  _WorkoutFlowPhase.summary => RestScreen(
    setReport: _currentSetReport!,
    setIndex: _currentSet - 1,
    totalSets: _spec.sets,
    showFatigueQuestion: _shouldAskFatigueQuestion(),
    onNext: _handleSummaryNext,
  ),

  _WorkoutFlowPhase.executive => ExecutiveSummaryPage(
    report: _fullReport!,
    userWeightKg: _userWeight,
    totalDuration: DateTime.now().difference(_startedAt!),
    onDone: () => Navigator.of(context).pop(),
  ),
*/

// ═══════════════════════════════════════════════════════════════
// GENERIC FALLBACK
// ═══════════════════════════════════════════════════════════════

/// Minimal builder for exercises without a custom implementation.
/// Inherits buildReport() and generateCoachText() from base.
/// Only implements the 3 required methods with simple defaults.
class GenericReportBuilder extends ExerciseReportBuilder {
  @override
  (String, String, String?) pickInsight(
    ExerciseLogger logger,
    ExerciseLogger? prevLogger,
    int score,
    int? prevScore,
  ) {
    final maxRep = (logger.setLogs["max_rep"] as num?)?.toInt() ?? 0;
    final goodReps = (logger.setLogs["good_rep_count"] as num?)?.toInt() ?? 0;
    if (maxRep == 0) return ('⚠️', 'Không có rep nào.', null);
    if (goodReps == maxRep)
      return ('✨', 'Hoàn hảo! $maxRep/$maxRep đúng form.', null);
    return ('📊', '$goodReps/$maxRep rep đúng form.', null);
  }

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;

  @override
  List<DetailCard> buildDetailCards(List<ExerciseLogger> setLoggers) {
    final allReps = setLoggers.expand((l) => l.repLogs).toList();
    if (allReps.isEmpty) return [];
    final totalGood = allReps.where((r) => r.correctForm).length;
    final accuracy = (totalGood / allReps.length * 100).roundToDouble();
    return [
      DetailCard(
        label: 'Độ chính xác',
        value: '${accuracy.round()}%',
        subLabel: '$totalGood/${allReps.length} rep',
        useRadial: true,
        radialValue: accuracy,
        color: 'jade',
      ),
    ];
  }
}
