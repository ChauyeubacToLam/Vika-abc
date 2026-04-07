import '../models/post_exercise_data.dart';
import '../squat/squat_report_builder.dart';
import '../glute_bridge/glute_bridge_report_builder.dart';

// ═══════════════════════════════════════════════════════════════
// REGISTRY — maps exercise ID to its report builder
// ═══════════════════════════════════════════════════════════════

/// When adding a new exercise:
/// 1. Create FooReportBuilder extending ExerciseReportBuilder
/// 2. Add entry here
/// 3. Done — UI works automatically
const Map<String, ({ExerciseReportBuilder builder, double met})>
    reportBuilders = {
  'squat': (builder: SquatReportBuilder(), met: 5.0),
  'squat_assessment': (builder: SquatReportBuilder(), met: 5.0),
  'glute_bridge': (builder: GluteBridgeReportBuilder(), met: 3.5),
  // 'wall_push_up': (builder: WallPushUpReportBuilder(), met: 3.0),
  // 'kneeling_hip_flexor_stretch': (builder: KneelingHFSReportBuilder(), met: 2.5),
  // 'bird_dog': (builder: BirdDogReportBuilder(), met: 3.0),
};

// ═══════════════════════════════════════════════════════════════
// INTEGRATION — how ExerciseExperienceScreen uses it
// ═══════════════════════════════════════════════════════════════

/*
  In exercise_experience_screen.dart, replace direct squat imports with:

  ┌─────────────────────────────────────────────────────────────┐
  │ BEFORE (current code):                                      │
  │                                                             │
  │   import '../../exercise/squat/squat.dart';                 │
  │   // SetSummaryPage reads SquatConfig directly              │
  │   // ExecutiveSummaryPage imports squat.dart                │
  │   // Issue detection hardcoded to heel_rise + depth         │
  │                                                             │
  │ AFTER (generic):                                            │
  │                                                             │
  │   import '../../models/post_exercise_data.dart';            │
  │   import '../../exercise/report_builder_registry.dart';     │
  │   // UI screens receive PostExerciseData only               │
  │   // No exercise-specific imports in any UI file            │
  └─────────────────────────────────────────────────────────────┘

  The ExerciseExperienceScreen builds the report when transitioning
  from active → summary:

  ```dart
  // In _handleSetComplete(ExerciseLogger logger):
  void _handleSetComplete(ExerciseLogger logger) {
    _setLoggers.add(logger);

    if (_isAssessment) {
      Navigator.of(context).pop({'logger': logger});
      return;
    }

    // Build set report for the rest screen
    _currentSetReport = _buildSetReport(logger, _setLoggers.length - 1);

    setState(() {
      _phase = _WorkoutFlowPhase.summary;
    });
  }

  SetReportData _buildSetReport(ExerciseLogger logger, int setIndex) {
    final entry = reportBuilders[widget.definition.id];
    if (entry == null) {
      // Fallback for exercises without a builder yet
      return _buildGenericSetReport(logger, setIndex);
    }

    // Build full report just to get this set's data
    // (cheap — just reading maps, no I/O)
    final report = entry.builder.buildReport(
      setLoggers: _setLoggers,
      exerciseName: widget.definition.name,
      metValue: entry.met,
    );
    return report.sets[setIndex];
  }
  ```

  When transitioning to executive summary:

  ```dart
  // In _handleSummaryNext():
  void _handleSummaryNext() {
    if (_currentSet >= _spec.sets) {
      // Build the full report for executive
      final entry = reportBuilders[widget.definition.id];
      _fullReport = entry?.builder.buildReport(
        setLoggers: _setLoggers,
        exerciseName: widget.definition.name,
        metValue: entry.met,
      );
      setState(() {
        _phase = _WorkoutFlowPhase.executive;
      });
      return;
    }
    _currentSet += 1;
    _startSet();
  }
  ```

  Then the UI screens receive the data:

  ```dart
  // Rest screen — receives SetReportData
  _WorkoutFlowPhase.summary => RestScreen(
    setReport: _currentSetReport!,
    setIndex: _currentSet - 1,
    totalSets: _spec.sets,
    prevSetReport: _setLoggers.length > 1
        ? _buildSetReport(_setLoggers[_setLoggers.length - 2],
            _currentSet - 2)
        : null,
    onNext: _handleSummaryNext,
  ),

  // Executive — receives full PostExerciseData
  _WorkoutFlowPhase.executive => ExecutiveSummaryPage(
    report: _fullReport!,
    userWeightKg: _userWeight, // from SharedPreferences
    totalDuration: DateTime.now().difference(_startedAt!),
    onDone: () => Navigator.of(context).pop(),
    onIssueAnswer: (key, answer) => _persistIssueAnswer(key, answer),
    onDifficultyAnswer: (difficulty) => _persistDifficulty(difficulty),
  ),
  ```

  The UI files (set_summary_page.dart, executive_summary_page.dart)
  ONLY import post_exercise_data.dart. They render from the generic
  data classes. Zero exercise knowledge.
*/

// ═══════════════════════════════════════════════════════════════
// GENERIC FALLBACK — for exercises that don't have a builder yet
// ═══════════════════════════════════════════════════════════════

/// Minimal report for exercises without a custom builder.
/// Shows basic rep accuracy + generic coaching. No fatigue detection,
/// no issue detection, no exercise-specific insights.
class GenericReportBuilder extends ExerciseReportBuilder {
  @override
  PostExerciseData buildReport({
    required List<dynamic> setLoggers,
    required String exerciseName,
    required double metValue,
  }) {
    final loggers = setLoggers.cast<ExerciseLogger>();
    final sets = <SetReportData>[];

    for (int i = 0; i < loggers.length; i++) {
      final reps = loggers[i].repLogs;
      final results = reps.map((r) => r.correctForm).toList();
      final good = results.where((r) => r).length;
      final total = results.length;
      final score = total > 0 ? (good / total * 100).round() : 0;

      sets.add(SetReportData(
        setIndex: i,
        score: score,
        goodReps: good,
        totalReps: total,
        repResults: results,
        insightIcon: good == total ? '✨' : '📊',
        insightText: '$good/$total rep đúng form.',
      ));
    }

    final allReps = loggers.expand((l) => l.repLogs).toList();
    final totalGood = allReps.where((r) => r.correctForm).length;
    final formScore =
        allReps.isEmpty ? 0 : (totalGood / allReps.length * 100).round();
    final setScores = sets.map((s) => s.score).toList();

    return PostExerciseData(
      exerciseName: exerciseName,
      metValue: metValue,
      sets: sets,
      formScore: formScore,
      coachText: generateCoachText(
          setScores, sets.length >= 2 && sets.last.score >= sets.first.score),
      detailCards: [
        DetailCard(
          label: 'Độ chính xác',
          value: '$formScore%',
          subLabel: '$totalGood/${allReps.length} rep',
          useRadial: true,
          radialValue: formScore.toDouble(),
          color: 'jade',
        ),
      ],
    );
  }

  @override
  (bool, String?, String?) detectFatigue(dynamic logger) => (false, null, null);

  @override
  (String, String, String?) pickInsight(
          dynamic logger, dynamic prev, int score, int? prevScore) =>
      ('📊', 'Hoàn thành set.', null);

  @override
  IssueQuestion? detectIssue(List<dynamic> setLoggers) => null;

  @override
  String generateCoachText(List<int> setScores, bool improved) =>
      improved ? 'Tốt hơn qua từng set!' : 'Giữ form ổn định.';

  @override
  List<DetailCard> buildDetailCards(List<dynamic> setLoggers) => [];
}
