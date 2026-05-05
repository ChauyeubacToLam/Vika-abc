import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../exercise/exercise_base.dart';
import '../../exercise/calorie_estimator_registry.dart';
import '../../exercise/glute bridge/glute_bridge.dart';
import '../../exercise/jumping jack/jumping_jack.dart';
import '../../exercise/lunge/lunge.dart';
import '../../exercise/plank/plank.dart';
import '../../exercise/push up/push_up.dart';
import '../../exercise/report_builder_registry.dart';
import '../../exercise/squat/metrics/heel_rise_metric.dart';
import '../../exercise/squat/metrics/tempo_metric.dart';
import '../../exercise/squat/metrics/trunk_lean_metric.dart';
import '../../exercise/squat/squat.dart';
import '../../models/exercise_definition.dart';
import '../../models/post_exercise_data.dart';
import '../../utils/exercise_logger.dart';
import 'active_exercise_page.dart';
import 'exercise_intro_page.dart';
import 'executive_summary_page.dart';
import 'rest_screen.dart';
import 'widgets/skeleton_annotation.dart';
import 'package:vika/services/session_persistence.dart';
import 'package:vika/services/exercise_comparison_service.dart';

class ExerciseExperienceScreen extends StatefulWidget {
  const ExerciseExperienceScreen({
    super.key,
    required this.definition,
  });

  final ExerciseDefinition definition;

  @override
  State<ExerciseExperienceScreen> createState() =>
      _ExerciseExperienceScreenState();
}

class _ExerciseExperienceScreenState extends State<ExerciseExperienceScreen> {
  late final _ExerciseExperienceSpec _spec;
  _WorkoutFlowPhase _phase = _WorkoutFlowPhase.intro;
  final List<ExerciseLogger> _setLoggers = [];
  final Map<int, Map<String, dynamic>> _difficultyLogs = {};

  ExerciseBase? _activeExercise;
  PostExerciseData? _fullReport;
  SetReportData? _currentSetReport;
  ExerciseLogger? _currentSetLogger;
  Duration? _completedDuration;
  int? _estimatedCalories;
  SessionComparison? _comparison;
  String? _currentSessionId;
  String? _pendingOverallDifficulty;

  int _currentSet = 1;
  int _currentRepsTarget = 0;
  int? _pendingNextRepsTarget;
  double _userWeightKg = 60;
  DateTime? _startedAt;

  String _coachNote =
      'Buổi này AI sẽ ưu tiên nhịp chậm, form chắc và sự ổn định trong từng rep.';

  // User-level data loaded once at screen init, passed to comparison service.
  UserStats? _userStats;
  List<String> _painAreas = [];
  List<PreviousSessionSummary> _sessionHistory = [];

  bool get _isAssessment => widget.definition.id.endsWith('_assessment');

  void _setFlowState(VoidCallback mutation) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(mutation);
    });
  }

  @override
  void initState() {
    super.initState();
    _spec = _ExerciseExperienceSpec.fromDefinition(widget.definition);
    _currentRepsTarget = _spec.repsPerSet;
    _loadCoachNote();
    _loadUserWeight();
    _loadSessionHistory();
    _loadUserStats();
    _loadPainAreas();
  }

  Future<void> _loadUserWeight() async {
    final prefs = await SharedPreferences.getInstance();
    final storedWeight = prefs.getDouble('user_weight');
    if (!mounted || storedWeight == null) return;
    setState(() => _userWeightKg = storedWeight);
  }

  Future<void> _loadUserStats() async {
    final stats = await SessionPersistence().getUserStats();
    if (!mounted) return;
    setState(() => _userStats = stats);
  }

  Future<void> _loadPainAreas() async {
    final areas = await SessionPersistence().getActivePainAreas();
    if (!mounted) return;
    setState(() => _painAreas = areas);
  }

  Future<void> _loadSessionHistory() async {
    if (_isAssessment) return;
    final history =
        await SessionPersistence().getSessionHistory(widget.definition.id);
    if (!mounted) return;
    setState(() {
      _sessionHistory = history;
      // Apply conservative adjustment from last session's self-reported
      // difficulty: heavy = -1 rep, light = +1 rep, else no change.
      // Only applied before workout starts (intro phase).
      if (_phase == _WorkoutFlowPhase.intro && history.isNotEmpty) {
        final lastDifficulty = history.last.overallDifficulty;
        final base = _spec.repsPerSet;
        _currentRepsTarget = switch (lastDifficulty) {
          'heavy' => (base - 1).clamp(1, base),
          'light' => base + 1,
          _ => base,
        };
      }
    });
  }

  Future<void> _loadCoachNote() async {
    final prefs = await SharedPreferences.getInstance();
    final level = prefs.getString('user_level') ?? 'beginner';
    final issues = prefs.getStringList('detected_issues') ?? const [];

    String note;
    if (issues.contains('ankle_mobility_restriction')) {
      note =
          'Buổi này AI sẽ ưu tiên giữ gót chân ổn định và giảm xu hướng đổ người về trước khi bạn xuống squat.';
    } else if (issues.contains('hip_flexor_overactivity')) {
      note =
          'Buổi này AI sẽ tập trung vào kiểm soát thân trên và giữ nhịp xuống chắc hơn để bạn không phải gập người quá nhiều.';
    } else if (issues.contains('ankle_mobility')) {
      note =
          'Buổi này AI sẽ chú ý thêm phần gót chân và độ sâu vì lần đánh giá trước cho thấy mắt cá còn hơi cứng.';
    } else if (issues.contains('limited_mobility')) {
      note =
          'AI sẽ ưu tiên độ sâu và nhịp xuống ổn định để bạn vào squat sâu hơn nhưng vẫn an toàn.';
    } else if (level == 'beginner') {
      note =
          'Buổi này AI tập trung vào nhịp xuống chậm, giữ đáy vững và cảm giác kiểm soát toàn bộ thân người.';
    } else {
      note =
          'AI sẽ theo dõi độ sâu, nhịp và độ ổn định để bạn giữ form sắc nét hơn trong toàn bộ buổi tập.';
    }

    if (mounted) {
      setState(() => _coachNote = note);
    }
  }

  void _beginWorkout() {
    setState(() {
      _setLoggers.clear();
      _difficultyLogs.clear();
      _fullReport = null;
      _currentSetReport = null;
      _currentSetLogger = null;
      _completedDuration = null;
      _estimatedCalories = null;
      _comparison = null;
      _currentSessionId = null;
      _pendingOverallDifficulty = null;
      _currentSet = 1;
      _currentRepsTarget = _spec.repsPerSet;
      _pendingNextRepsTarget = null;
      _startedAt = DateTime.now();
      _prepareActiveSet();
    });
  }

  void _prepareActiveSet() {
    _currentSetReport = null;
    _currentSetLogger = null;
    _activeExercise = _spec.createExercise(_currentRepsTarget);
    _phase = _WorkoutFlowPhase.active;
  }

  ({ExerciseReportBuilder builder, double met}) _resolveReportEntry() {
    return reportBuilders[widget.definition.id] ??
        (builder: GenericReportBuilder(), met: 3.5);
  }

  PostExerciseData _buildReport() {
    final entry = _resolveReportEntry();
    return entry.builder.buildReport(
      setLoggers: _setLoggers,
      exerciseName: widget.definition.name,
      metValue: entry.met,
      history: _sessionHistory,
      userPainAreas: _painAreas,
    );
  }

  int _estimateCalories({
    required PostExerciseData report,
    required Duration totalDuration,
  }) {
    final estimator = calorieEstimators[widget.definition.id] ??
        const GenericMetCalorieEstimator();
    return estimator.estimateCalories(
      setLoggers: _setLoggers,
      report: report,
      userWeightKg: _userWeightKg,
      totalDuration: totalDuration,
    );
  }

  void _handleSetComplete(ExerciseLogger logger) {
    _setLoggers.add(logger);

    if (_isAssessment) {
      Navigator.of(context).pop({'logger': logger});
      return;
    }

    final report = _buildReport();

    _setFlowState(() {
      _currentSetReport = report.sets.last;
      _currentSetLogger = logger;
      _activeExercise = null;
      _phase = _WorkoutFlowPhase.rest;
    });
  }

  Future<void> _persistDifficultyLog(Map<String, dynamic> payload) async {
    _difficultyLogs[payload['set_index'] as int] = payload;
    final prefs = await SharedPreferences.getInstance();
    final orderedLogs = _difficultyLogs.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    await prefs.setStringList(
      'exercise_difficulty_${widget.definition.id}',
      orderedLogs.map((entry) => jsonEncode(entry.value)).toList(),
    );
  }

  void _handleDifficultyAnswer(String difficulty) {
    final isLastSet = _currentSet >= _spec.sets;
    final restSeconds =
        (isLastSet ? 10 : 45) + (difficulty == 'heavy' ? 15 : 0);
    final nextReps = switch (difficulty) {
      'light' => _currentRepsTarget + 2,
      'heavy' => _currentRepsTarget > 1 ? _currentRepsTarget - 1 : 1,
      _ => _currentRepsTarget,
    };

    _pendingNextRepsTarget = nextReps;
    _persistDifficultyLog({
      'set_index': _currentSetReport?.setIndex ?? (_currentSet - 1),
      'set_score': _currentSetReport?.score ?? 0,
      'difficulty': difficulty,
      'reps_completed': _currentSetReport?.totalReps ?? 0,
      'rest_time_seconds': restSeconds,
    });
  }

  /// Aggregate fault counts across all sets. Pure function: returns a map,
  /// doesn't mutate fields. Call this whenever fresh totals are needed.
  Map<String, int> _aggregateFaultCounts(List<ExerciseLogger> setLoggers) {
    final counts = <String, int>{};
    for (final logger in setLoggers) {
      for (final entry in logger.setLogs.entries) {
        if (entry.key.endsWith('_fails_count') && entry.value is num) {
          counts[entry.key] =
              (counts[entry.key] ?? 0) + (entry.value as num).toInt();
        }
      }
    }
    return counts;
  }

  List<Map<String, dynamic>> _buildSetData(List<ExerciseLogger> setLogs) {
    return setLogs.asMap().entries.map((entry) {
      final i = entry.key;
      final logger = entry.value;
      return {
        'set_index': i,
        'good_reps': logger.setLogs['good_rep_count'] ?? 0,
        'total_reps': logger.repLogs.length,
        'rep_data': logger.repLogs
            .map((r) => {
                  'rep_number': r.repNumber,
                  'correct_form': r.correctForm,
                  'data': r.data,
                })
            .toList(),
      };
    }).toList();
  }

  Future<void> _persistSession(PostExerciseData report) async {
    final faultCounts = _aggregateFaultCounts(_setLoggers);
    final setData = _buildSetData(_setLoggers);

    // Fixed-length list: one slot per set, null if user skipped rating that set.
    // Preserves set ordering so set 2's rating is always at index 1.
    final ratings = List<String?>.generate(
      report.sets.length,
      (i) => _difficultyLogs[i]?['difficulty'] as String?,
    );

    final sessionId = await SessionPersistence().saveSession(
      exerciseId: widget.definition.id,
      startedAt: _startedAt ?? DateTime.now(),
      formScore: report.formScore,
      totalReps: report.sets.fold(0, (sum, s) => sum + s.totalReps),
      totalGoodReps: report.sets.fold(0, (sum, s) => sum + s.goodReps),
      totalSets: report.sets.length,
      calories: _estimatedCalories,
      faultCounts: faultCounts,
      difficultyRatings: ratings,
      setData: setData,
    );

    debugPrint('[Vika] Session persisted: $sessionId');

    if (sessionId != null) {
      _currentSessionId = sessionId;

      // Flush queued difficulty even if the screen has already been popped.
      final pending = _pendingOverallDifficulty;
      if (pending != null) {
        _pendingOverallDifficulty = null;
        await SessionPersistence().updateSessionDifficulty(
          sessionId: sessionId,
          difficulty: pending,
        );
      }
    }

    // Update streak on profiles after successful session write.
    // Fire-and-forget — errors don't block UX.
    await SessionPersistence().updateStreak();
  }

  /// Called from ExecutiveSummaryPage when user taps a difficulty emoji.
  /// Writes to exercise_sessions.overall_difficulty for the current session.
  /// If the session save hasn't completed yet, queues the answer and flushes
  /// it once _currentSessionId becomes available.
  void _handleOverallDifficulty(String difficulty) {
    final sessionId = _currentSessionId;
    if (sessionId == null) {
      debugPrint('[Vika] Queueing difficulty until session save completes');
      _pendingOverallDifficulty = difficulty;
      return;
    }
    SessionPersistence().updateSessionDifficulty(
      sessionId: sessionId,
      difficulty: difficulty,
    );
  }

  void _handleSummaryNext() {
    if (_currentSet >= _spec.sets) {
      final report = _buildReport();
      final faultCounts = _aggregateFaultCounts(_setLoggers);
      final completedDuration =
          DateTime.now().difference(_startedAt ?? DateTime.now());

      final builderEntry = reportBuilders[widget.definition.id];
      SessionComparison? comparison;
      if (builderEntry != null) {
        comparison = ExerciseComparisonService().buildExecutiveComparison(
          currentFormScore: report.formScore,
          currentFaultCounts: faultCounts,
          history: _sessionHistory,
          userPainAreas: _painAreas,
          painToFaultMap: builderEntry.builder.painToFaultMap(),
          faultLabels: builderEntry.builder.praiseMetricNames(),
          streakLength: _userStats?.streakDays ?? 0,
        );
      }

      _setFlowState(() {
        _fullReport = report;
        _completedDuration = completedDuration;
        _estimatedCalories = _estimateCalories(
          report: report,
          totalDuration: completedDuration,
        );
        _comparison = comparison;
        _activeExercise = null;
        _phase = _WorkoutFlowPhase.executive;
      });

      if (!_isAssessment) {
        _persistSession(report);
      }
      return;
    }

    _setFlowState(() {
      _currentSet += 1;
      _currentRepsTarget = _pendingNextRepsTarget ?? _currentRepsTarget;
      _pendingNextRepsTarget = null;
      _prepareActiveSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (_phase) {
      _WorkoutFlowPhase.active => const Color(0xFF15110D),
      _ => const Color(0xFFF0EDE6),
    };
    final phaseBody = switch (_phase) {
      _WorkoutFlowPhase.intro => ExerciseIntroPage(
          title: widget.definition.name,
          difficulty: widget.definition.difficulty,
          totalSets: _spec.sets,
          repsPerSet: _spec.repsPerSet,
          videoDuration: _spec.videoDuration,
          muscles: _spec.muscles,
          tips: _spec.tips,
          badges: _spec.badges,
          callouts: _spec.callouts,
          coachNote: _coachNote,
          onStart: _beginWorkout,
          onBack: () => Navigator.of(context).pop(),
        ),
      _WorkoutFlowPhase.active => ActiveExercisePage(
          definition: widget.definition,
          exercise: _activeExercise!,
          currentSet: _currentSet,
          totalSets: _spec.sets,
          totalReps: _currentRepsTarget,
          onSetComplete: _handleSetComplete,
          onBack: () => Navigator.of(context).pop(),
        ),
      _WorkoutFlowPhase.rest => RestScreen(
          setReport: _currentSetReport!,
          setIndex: _currentSet - 1,
          totalSets: _spec.sets,
          currentReps: _currentRepsTarget,
          isLastSet: _currentSet >= _spec.sets,
          setLogger: _currentSetLogger,
          onNext: _handleSummaryNext,
          previousSession: _sessionHistory,
          onDifficultyAnswer: _handleDifficultyAnswer,
        ),
      _WorkoutFlowPhase.executive => ExecutiveSummaryPage(
          report: _fullReport!,
          comparison: _comparison,
          calories: _estimatedCalories ?? 0,
          userWeightKg: _userWeightKg,
          totalDuration: _completedDuration ?? Duration.zero,
          isFirstSession: _sessionHistory.isEmpty,
          streakDays: _userStats?.streakDays ?? 0,
          lastOverallDifficulty: _sessionHistory.isNotEmpty
              ? _sessionHistory.last.overallDifficulty
              : null,
          onOverallDifficulty: _handleOverallDifficulty,
          onDone: () => Navigator.of(context).pop(),
        ),
    };

    return Scaffold(
      backgroundColor: backgroundColor,
      body: phaseBody,
    );
  }
}

enum _WorkoutFlowPhase { intro, active, rest, executive }

class _ExerciseExperienceSpec {
  const _ExerciseExperienceSpec({
    required this.sets,
    required this.repsPerSet,
    required this.videoDuration,
    required this.muscles,
    required this.tips,
    required this.badges,
    required this.callouts,
    required this.createExercise,
  });

  final int sets;
  final int repsPerSet;
  final String videoDuration;
  final List<String> muscles;
  final List<String> tips;
  final List<ExerciseIntroBadge> badges;
  final List<SkeletonCallout> callouts;
  final ExerciseBase Function(int repsPerSet) createExercise;

  factory _ExerciseExperienceSpec.fromDefinition(
    ExerciseDefinition definition,
  ) {
    switch (definition.id) {
      case 'squat_assessment':
        return _ExerciseExperienceSpec(
          sets: 1,
          repsPerSet: 5,
          videoDuration: '1:18',
          muscles: definition.targetMuscles,
          tips: definition.setupTips,
          badges: [
            ExerciseIntroBadge(
              title: 'Nhịp xuống',
              value: '≥ ${TempoConfig.DESCENT_MIN_GOOD}s',
              color: const Color(0xFF2B5EA6),
            ),
            ExerciseIntroBadge(
              title: 'Giữ đáy',
              value: '≥ ${TempoConfig.BOTTOM_HOLD_MIN}s',
              color: const Color(0xFF7040B8),
            ),
          ],
          callouts: [
            SkeletonCallout(
              title: 'Lưng nghiêng',
              value:
                  '${TrunkLeanConfig.GOOD_LEAN_RANGE[0]}° — ${TrunkLeanConfig.GOOD_LEAN_RANGE[1]}°',
              color: const Color(0xFFB87320),
              alignment: const Alignment(0.90, -0.40),
              anchor: const Offset(0.24, 0.56),
            ),
            SkeletonCallout(
              title: 'Độ sâu gối',
              value:
                  '${SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[0]}° — ${SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1]}°',
              color: const Color(0xFF1B6B52),
              alignment: const Alignment(0.90, -0.02),
              anchor: const Offset(0.16, 0.72),
            ),
            SkeletonCallout(
              title: 'Gót chân',
              value:
                  'Nhấc < ${(HeelRiseConfig.LIFT_THRESHOLD * 100).round()}% chiều dài lưng',
              color: const Color(0xFFB84435),
              alignment: const Alignment(0.90, 0.34),
              anchor: const Offset(0.20, 0.88),
            ),
          ],
          createExercise: (repsPerSet) => Squat(maxRep: repsPerSet),
        );
      case 'wall_pushup_assessment':
        return _generic(
          definition: definition,
          sets: 1,
          repsPerSet: 5,
          videoDuration: '1:12',
          createExercise: (repsPerSet) => PushUp(maxRep: repsPerSet),
        );
      case 'squat':
        return _ExerciseExperienceSpec(
          sets: 3,
          repsPerSet: 8,
          videoDuration: '2:15',
          muscles: definition.targetMuscles,
          tips: definition.setupTips,
          badges: [
            ExerciseIntroBadge(
              title: 'Nhịp xuống',
              value: '≥ ${TempoConfig.DESCENT_MIN_GOOD}s',
              color: const Color(0xFF2B5EA6),
            ),
            ExerciseIntroBadge(
              title: 'Giữ đáy',
              value: '≥ ${TempoConfig.BOTTOM_HOLD_MIN}s',
              color: const Color(0xFF7040B8),
            ),
          ],
          callouts: [
            SkeletonCallout(
              title: 'Lưng nghiêng',
              value:
                  '${TrunkLeanConfig.GOOD_LEAN_RANGE[0]}° — ${TrunkLeanConfig.GOOD_LEAN_RANGE[1]}°',
              color: const Color(0xFFB87320),
              alignment: const Alignment(0.90, -0.40),
              anchor: const Offset(0.24, 0.56),
            ),
            SkeletonCallout(
              title: 'Độ sâu gối',
              value:
                  '${SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[0]}° — ${SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1]}°',
              color: const Color(0xFF1B6B52),
              alignment: const Alignment(0.90, -0.02),
              anchor: const Offset(0.16, 0.72),
            ),
            SkeletonCallout(
              title: 'Gót chân',
              value:
                  'Nhấc < ${(HeelRiseConfig.LIFT_THRESHOLD * 100).round()}% chiều dài lưng',
              color: const Color(0xFFB84435),
              alignment: const Alignment(0.90, 0.34),
              anchor: const Offset(0.20, 0.88),
            ),
          ],
          createExercise: (repsPerSet) => Squat(maxRep: repsPerSet),
        );
      case 'lunge':
        return _generic(
          definition: definition,
          repsPerSet: 8,
          videoDuration: '1:58',
          createExercise: (repsPerSet) => Lunge(maxRep: repsPerSet),
        );
      case 'push_up':
        return _generic(
          definition: definition,
          repsPerSet: 6,
          videoDuration: '1:42',
          createExercise: (repsPerSet) => PushUp(maxRep: repsPerSet),
        );
      case 'plank':
        return _generic(
          definition: definition,
          repsPerSet: 3,
          videoDuration: '1:28',
          createExercise: (repsPerSet) => Plank(maxRep: repsPerSet),
        );
      case 'jumping_jack':
        return _generic(
          definition: definition,
          repsPerSet: 15,
          videoDuration: '1:10',
          createExercise: (repsPerSet) => JumpingJack(maxRep: repsPerSet),
        );
      case 'glute_bridge':
        return _generic(
          definition: definition,
          repsPerSet: 15,
          videoDuration: '1:36',
          createExercise: (_) => GluteBridge(),
        );
      default:
        return _generic(
          definition: definition,
          repsPerSet: 8,
          videoDuration: '1:30',
          createExercise: (_) => definition.createExercise(),
        );
    }
  }

  static _ExerciseExperienceSpec _generic({
    required ExerciseDefinition definition,
    int sets = 3,
    required int repsPerSet,
    required String videoDuration,
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
      videoDuration: videoDuration,
      muscles: definition.targetMuscles,
      tips: definition.setupTips,
      badges: [
        ExerciseIntroBadge(
          title: 'Nhịp tập',
          value: 'Ổn định',
          color: const Color(0xFF2B5EA6),
        ),
        ExerciseIntroBadge(
          title: 'Kiểm soát',
          value: 'Có AI theo dõi',
          color: const Color(0xFF7040B8),
        ),
      ],
      callouts: [
        SkeletonCallout(
          title: 'Tư thế thân trên',
          value: 'Giữ ổn định',
          color: const Color(0xFFB87320),
          alignment: const Alignment(0.90, -0.40),
          anchor: const Offset(0.24, 0.56),
        ),
        SkeletonCallout(
          title: 'Biên độ chính',
          value: 'Theo dõi liên tục',
          color: const Color(0xFF1B6B52),
          alignment: const Alignment(0.90, -0.02),
          anchor: const Offset(0.16, 0.72),
        ),
        SkeletonCallout(
          title: 'Nhịp chuyển động',
          value: 'Mượt và đều',
          color: const Color(0xFFB84435),
          alignment: const Alignment(0.90, 0.34),
          anchor: const Offset(0.20, 0.88),
        ),
      ],
      createExercise: createExercise,
    );
  }
}
