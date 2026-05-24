import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../exercise/exercise_base.dart';
import '../../exercise/calorie_estimator_registry.dart';
import '../../exercise/curl_up/curl_up.dart';
import '../../exercise/glute bridge/glute_bridge.dart';
import '../../exercise/glute bridge/metrics/glute_bridge_hip_extension.dart'
    as bridge_hip;
import '../../exercise/glute bridge/metrics/glute_bridge_knee_angle.dart'
    as bridge_knee;
import '../../exercise/glute bridge/metrics/glute_bridge_neck_head.dart'
    as bridge_neck;
import '../../exercise/glute bridge/metrics/glute_bridge_speed_control.dart'
    as bridge_speed;
import '../../exercise/jumping jack/jumping_jack.dart';
import '../../exercise/jumping jack/metrics/arm_extension_metric.dart'
    as jj_arm;
import '../../exercise/jumping jack/metrics/leg_spread_metric.dart' as jj_leg;
import '../../exercise/jumping jack/metrics/tempo_metric.dart' as jj_tempo;
import '../../exercise/lunge/lunge.dart';
import '../../exercise/lunge/metrics/lunge_depth_metric.dart' as lunge_depth;
import '../../exercise/lunge/metrics/lunge_heel_lift_metric.dart' as lunge_heel;
import '../../exercise/lunge/metrics/lunge_lumbar_proxy_metric.dart'
    as lunge_core;
import '../../exercise/lunge/metrics/lunge_trunk_lean_metric.dart'
    as lunge_trunk;
import '../../exercise/plank/plank.dart';
import '../../exercise/plank/metrics/head_neck_metric.dart' as plank_neck;
import '../../exercise/plank/metrics/knee_extension_metric.dart' as plank_knee;
import '../../exercise/plank/metrics/trunk_alignment_metric.dart'
    as plank_trunk;
import '../../exercise/push up/push_up.dart';
import '../../exercise/push up/metrics/depth_metric.dart' as push_depth;
import '../../exercise/push up/metrics/tempo_metric.dart' as push_tempo;
import '../../exercise/push up/metrics/trunk_alignment_metric.dart'
    as push_trunk;
import '../../exercise/report_builder_registry.dart';
import '../../exercise/curl_up/metrics/curl_up_knee_extension.dart'
    as curl_knee;
import '../../exercise/curl_up/metrics/curl_up_neck_pulling.dart' as curl_neck;
import '../../exercise/curl_up/metrics/curl_up_trunk_elevation.dart'
    as curl_trunk;
import '../../exercise/squat/metrics/heel_rise_metric.dart';
import '../../exercise/squat/metrics/tempo_metric.dart';
import '../../exercise/squat/metrics/trunk_lean_metric.dart';
import '../../exercise/squat/squat.dart';
import '../../models/exercise_definition.dart';
import '../../models/post_exercise_data.dart';
import '../../services/recommendation/models/plan.dart';
import '../../services/recommendation/progression_service.dart';
import '../../utils/exercise_logger.dart';
import '../../utils/orientation_lock.dart';
import 'active_exercise_page.dart';
import 'exercise_launch_args.dart';
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
    this.catalogExerciseId,
    this.prescription,
    this.recommendationId,
    this.weekNumber,
    this.sessionIndex,
    this.slotName,
    this.sequence = const [],
    this.sequenceIndex = 0,
  });

  final ExerciseDefinition definition;
  final String? catalogExerciseId;
  final VolumePrescription? prescription;
  final String? recommendationId;
  final int? weekNumber;
  final int? sessionIndex;
  final String? slotName;
  final List<ExerciseSequenceItem> sequence;
  final int sequenceIndex;

  @override
  State<ExerciseExperienceScreen> createState() =>
      _ExerciseExperienceScreenState();
}

class _ExerciseExperienceScreenState extends State<ExerciseExperienceScreen> {
  late final _ExerciseExperienceSpec _spec;
  _WorkoutFlowPhase _phase = _WorkoutFlowPhase.intro;
  final List<ExerciseLogger> _setLoggers = [];
  final Map<int, Map<String, dynamic>> _difficultyLogs = {};
  final Map<int, int> _prescribedRepsBySet = {};

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
  String get _sessionExerciseId =>
      widget.catalogExerciseId ?? widget.definition.id;
  bool get _isWorkoutSequence => widget.sequence.length > 1;
  bool get _isContinuationSlot =>
      _isWorkoutSequence && widget.sequenceIndex > 0;
  String? get _sessionProgressLabel => _isWorkoutSequence
      ? 'Buổi tập · Bài ${widget.sequenceIndex + 1}/${widget.sequence.length}'
      : null;
  ExerciseLaunchArgs? get _nextInSequence {
    final args = ExerciseLaunchArgs(
      definition: widget.definition,
      catalogExerciseId: widget.catalogExerciseId,
      prescription: widget.prescription,
      recommendationId: widget.recommendationId,
      weekNumber: widget.weekNumber,
      sessionIndex: widget.sessionIndex,
      slotName: widget.slotName,
      sequence: widget.sequence,
      sequenceIndex: widget.sequenceIndex,
    );
    return args.nextInSequence();
  }

  String get _summaryDoneLabel {
    final next = _nextInSequence;
    if (next != null) return 'Bài tiếp theo: ${next.definition.name}';
    if (_isWorkoutSequence) return 'Hoàn thành buổi tập';
    return 'Hoàn tất';
  }

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
    unawaited(OrientationLock.portraitOnly());
    _spec = _ExerciseExperienceSpec.fromDefinition(
      widget.definition,
      prescription: widget.prescription,
    );
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
        await SessionPersistence().getSessionHistory(_sessionExerciseId);
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
      _prescribedRepsBySet.clear();
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
    _prescribedRepsBySet[_currentSet - 1] = _currentRepsTarget;
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
      'exercise_difficulty_$_sessionExerciseId',
      orderedLogs.map((entry) => jsonEncode(entry.value)).toList(),
    );
  }

  void _handleDifficultyAnswer(String difficulty) {
    final isLastSet = _currentSet >= _spec.sets;
    final prescribedRest = isLastSet ? 10 : _spec.restSeconds;
    final restSeconds = prescribedRest + (difficulty == 'heavy' ? 15 : 0);
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
      'recommendation_difficulty':
          normalizeSetDifficultyForRecommendation(difficulty),
      'reps_completed': _currentSetReport?.totalReps ?? 0,
      'prescribed_reps': _currentRepsTarget,
      'prescribed_rest': prescribedRest,
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
      final difficultyLog = _difficultyLogs[i];
      final prescribedReps = _prescribedRepsBySet[i] ?? _spec.repsPerSet;
      final appliedRest = difficultyLog?['rest_time_seconds'] as int? ??
          (i == setLogs.length - 1 ? 10 : _spec.restSeconds);
      return {
        'set_index': i,
        'set_number': i + 1,
        'recommendation_id': widget.recommendationId,
        'week_number': widget.weekNumber,
        'session_index': widget.sessionIndex,
        'is_deload_week': widget.prescription?.isDeloadWeek ?? false,
        'prescribed_reps': prescribedReps,
        'actual_reps': logger.repLogs.length,
        'prescribed_rest':
            difficultyLog?['prescribed_rest'] ?? _spec.restSeconds,
        'applied_rest': appliedRest,
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
      (i) => _difficultyLogs[i]?['recommendation_difficulty'] as String?,
    );

    final sessionId = await SessionPersistence().saveSession(
      exerciseId: _sessionExerciseId,
      recommendationId: widget.recommendationId,
      slotName: widget.slotName,
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
      if (builderEntry != null && _sessionHistory.isNotEmpty) {
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
          targetLabel: _spec.targetLabel,
          secondsPerUnit: _spec.secondsPerUnit,
          muscles: _spec.muscles,
          tips: _spec.tips,
          badges: _spec.badges,
          callouts: _spec.callouts,
          posture: _spec.posture,
          coachNote: _coachNote,
          sessionProgressLabel: _sessionProgressLabel,
          isContinuation: _isContinuationSlot,
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
          baseRestSeconds: _spec.restSeconds,
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
          sessionProgressLabel: _sessionProgressLabel,
          doneLabel: _summaryDoneLabel,
          isFinalWorkoutSlot: _nextInSequence == null,
          onDone: () => Navigator.of(context).pop({
            'completed': true,
            'next': _nextInSequence,
          }),
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
    required this.restSeconds,
    required this.targetLabel,
    required this.secondsPerUnit,
    required this.posture,
    required this.muscles,
    required this.tips,
    required this.badges,
    required this.callouts,
    required this.createExercise,
  });

  final int sets;
  final int repsPerSet;
  final String videoDuration;
  final int restSeconds;
  final String targetLabel;
  final double secondsPerUnit;
  final SkeletonPosture posture;
  final List<String> muscles;
  final List<String> tips;
  final List<ExerciseIntroBadge> badges;
  final List<SkeletonCallout> callouts;
  final ExerciseBase Function(int repsPerSet) createExercise;

  factory _ExerciseExperienceSpec.fromDefinition(
    ExerciseDefinition definition, {
    VolumePrescription? prescription,
  }) {
    final overrideSets = prescription?.sets;
    final overrideReps = prescription?.reps;
    final overrideRest = prescription?.restSeconds;

    switch (definition.id) {
      case 'squat_assessment':
        return _ExerciseExperienceSpec(
          sets: 1,
          repsPerSet: 5,
          videoDuration: '1:18',
          restSeconds: overrideRest ?? 45,
          targetLabel: 'REP/HIỆP',
          secondsPerUnit: 4,
          posture: SkeletonPosture.standing,
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
        return _pushUpSpec(
          definition: definition,
          sets: 1,
          repsPerSet: 5,
          restSeconds: overrideRest,
          videoDuration: '1:12',
          createExercise: (repsPerSet) => PushUp(maxRep: repsPerSet),
        );
      case 'squat':
        return _ExerciseExperienceSpec(
          sets: overrideSets ?? 3,
          repsPerSet: overrideReps ?? 8,
          videoDuration: '2:15',
          restSeconds: overrideRest ?? 45,
          targetLabel: 'REP/HIỆP',
          secondsPerUnit: 4,
          posture: SkeletonPosture.standing,
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
        return _lungeSpec(
          definition: definition,
          sets: overrideSets ?? 3,
          repsPerSet: overrideReps ?? 8,
          restSeconds: overrideRest,
          videoDuration: '1:58',
          createExercise: (repsPerSet) => Lunge(maxRep: repsPerSet),
        );
      case 'push_up':
        return _pushUpSpec(
          definition: definition,
          sets: overrideSets ?? 3,
          repsPerSet: overrideReps ?? 6,
          restSeconds: overrideRest,
          videoDuration: '1:42',
          createExercise: (repsPerSet) => PushUp(maxRep: repsPerSet),
        );
      case 'plank':
        return _plankSpec(
          definition: definition,
          sets: overrideSets ?? 3,
          repsPerSet: overrideReps ?? 3,
          restSeconds: overrideRest,
          videoDuration: '1:28',
          createExercise: (repsPerSet) => Plank(maxRep: repsPerSet),
        );
      case 'jumping_jack':
        return _jumpingJackSpec(
          definition: definition,
          sets: overrideSets ?? 3,
          repsPerSet: overrideReps ?? 15,
          restSeconds: overrideRest,
          videoDuration: '1:10',
          createExercise: (repsPerSet) => JumpingJack(maxRep: repsPerSet),
        );
      case 'glute_bridge':
        return _gluteBridgeSpec(
          definition: definition,
          sets: overrideSets ?? 3,
          repsPerSet: overrideReps ?? 15,
          restSeconds: overrideRest,
          videoDuration: '1:36',
          createExercise: (repsPerSet) => GluteBridge(maxRep: repsPerSet),
        );
      case 'curl_up':
        return _curlUpSpec(
          definition: definition,
          sets: overrideSets ?? 3,
          repsPerSet: overrideReps ?? 12,
          restSeconds: overrideRest,
          videoDuration: '1:34',
          createExercise: (repsPerSet) => CurlUp(maxRep: repsPerSet),
        );
      default:
        return _generic(
          definition: definition,
          sets: overrideSets ?? 3,
          repsPerSet: overrideReps ?? 8,
          restSeconds: overrideRest,
          videoDuration: '1:30',
          createExercise: (_) => definition.createExercise(),
        );
    }
  }

  static _ExerciseExperienceSpec _generic({
    required ExerciseDefinition definition,
    int sets = 3,
    required int repsPerSet,
    int? restSeconds,
    required String videoDuration,
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
      videoDuration: videoDuration,
      restSeconds: restSeconds ?? 45,
      targetLabel: 'REP/HIỆP',
      secondsPerUnit: 4,
      posture: SkeletonPosture.standing,
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

  static _ExerciseExperienceSpec _lungeSpec({
    required ExerciseDefinition definition,
    required int sets,
    required int repsPerSet,
    int? restSeconds,
    required String videoDuration,
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
      videoDuration: videoDuration,
      restSeconds: restSeconds ?? 45,
      targetLabel: 'REP/HIỆP',
      secondsPerUnit: 4,
      posture: SkeletonPosture.standing,
      muscles: definition.targetMuscles,
      tips: definition.setupTips,
      badges: const [],
      callouts: [
        SkeletonCallout(
          title: 'Lưng nghiêng',
          value:
              '${lunge_trunk.LungeTrunkLeanConfig.GOOD_LEAN_RANGE[0]}° — ${lunge_trunk.LungeTrunkLeanConfig.GOOD_LEAN_RANGE[1]}°',
          color: const Color(0xFFB87320),
          alignment: const Alignment(0.90, -0.44),
          anchor: const Offset(0.24, 0.56),
        ),
        SkeletonCallout(
          title: 'Độ sâu gối',
          value:
              '${lunge_depth.LungeDepthConfig.GOOD_DEPTH_RANGE[0]}° — ${lunge_depth.LungeDepthConfig.GOOD_DEPTH_RANGE[1]}°',
          color: const Color(0xFF1B6B52),
          alignment: const Alignment(0.90, -0.05),
          anchor: const Offset(0.18, 0.73),
        ),
        SkeletonCallout(
          title: 'Gót chân',
          value:
              'Nhấc < ${(lunge_heel.LungeHeelLiftConfig.WARNING_THRESHOLD * 100).round()}% thân',
          color: const Color(0xFFB84435),
          alignment: const Alignment(0.90, 0.34),
          anchor: const Offset(0.20, 0.88),
        ),
        SkeletonCallout(
          title: 'Core & hông',
          value:
              '≥ ${lunge_core.LungeLumbarProxyConfig.GOOD_THRESHOLD.round()}°',
          color: const Color(0xFF2B5EA6),
          alignment: const Alignment(-0.90, -0.18),
          anchor: const Offset(0.35, 0.62),
        ),
      ],
      createExercise: createExercise,
    );
  }

  static _ExerciseExperienceSpec _pushUpSpec({
    required ExerciseDefinition definition,
    required int sets,
    required int repsPerSet,
    int? restSeconds,
    required String videoDuration,
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
      videoDuration: videoDuration,
      restSeconds: restSeconds ?? 45,
      targetLabel: 'REP/HIỆP',
      secondsPerUnit: 4,
      posture: SkeletonPosture.lyingFaceDown,
      muscles: definition.targetMuscles,
      tips: definition.setupTips,
      badges: [
        ExerciseIntroBadge(
          title: 'Nhịp xuống',
          value: '≥ ${push_tempo.TempoConfig.DESCENT_GOOD_MIN}s',
          color: const Color(0xFF2B5EA6),
        ),
      ],
      callouts: [
        SkeletonCallout(
          title: 'Thân người',
          value:
              'Võng < ${push_trunk.TrunkAlignmentConfig.SAG_GOOD_MAX.round()}°',
          color: const Color(0xFFB87320),
          alignment: const Alignment(0.90, -0.40),
          anchor: const Offset(0.38, 0.56),
        ),
        SkeletonCallout(
          title: 'Độ sâu khuỷu',
          value:
              '${push_depth.DepthConfig.goodDepthMin.round()}° — ${push_depth.DepthConfig.goodDepthMax.round()}°',
          color: const Color(0xFF1B6B52),
          alignment: const Alignment(0.90, -0.02),
          anchor: const Offset(0.22, 0.56),
        ),
        SkeletonCallout(
          title: 'Khoá khuỷu',
          value: '≥ ${push_depth.DepthConfig.LOCKOUT_ANGLE.round()}°',
          color: const Color(0xFFB84435),
          alignment: const Alignment(0.90, 0.34),
          anchor: const Offset(0.18, 0.52),
        ),
      ],
      createExercise: createExercise,
    );
  }

  static _ExerciseExperienceSpec _plankSpec({
    required ExerciseDefinition definition,
    required int sets,
    required int repsPerSet,
    int? restSeconds,
    required String videoDuration,
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
      videoDuration: videoDuration,
      restSeconds: restSeconds ?? PlankConfig.REST_DURATION.round(),
      targetLabel: 'LẦN GIỮ/HIỆP',
      secondsPerUnit: PlankConfig.HOLD_DURATION,
      posture: SkeletonPosture.lyingFaceDown,
      muscles: definition.targetMuscles,
      tips: definition.setupTips,
      badges: [
        ExerciseIntroBadge(
          title: 'Thời gian giữ',
          value: '${PlankConfig.HOLD_DURATION.round()}s',
          color: const Color(0xFF7040B8),
        ),
      ],
      callouts: [
        SkeletonCallout(
          title: 'Thân người',
          value:
              'Lệch < ${plank_trunk.TrunkAlignmentConfig.SAG_GOOD_MAX.toStringAsFixed(1)}°',
          color: const Color(0xFFB87320),
          alignment: const Alignment(0.90, -0.40),
          anchor: const Offset(0.38, 0.56),
        ),
        SkeletonCallout(
          title: 'Đầu cổ',
          value:
              'Lệch < ${plank_neck.HeadNeckConfig.WARNING_DEVIATION.round()}°',
          color: const Color(0xFF1B6B52),
          alignment: const Alignment(0.90, -0.02),
          anchor: const Offset(0.18, 0.50),
        ),
        SkeletonCallout(
          title: 'Đầu gối',
          value: '≥ ${plank_knee.KneeExtensionConfig.GOOD_MIN.round()}°',
          color: const Color(0xFFB84435),
          alignment: const Alignment(0.90, 0.34),
          anchor: const Offset(0.68, 0.60),
        ),
      ],
      createExercise: createExercise,
    );
  }

  static _ExerciseExperienceSpec _jumpingJackSpec({
    required ExerciseDefinition definition,
    required int sets,
    required int repsPerSet,
    int? restSeconds,
    required String videoDuration,
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
      videoDuration: videoDuration,
      restSeconds: restSeconds ?? 35,
      targetLabel: 'REP/HIỆP',
      secondsPerUnit: 1.2,
      posture: SkeletonPosture.standing,
      muscles: definition.targetMuscles,
      tips: definition.setupTips,
      badges: [
        ExerciseIntroBadge(
          title: 'Nhịp rep',
          value:
              '${jj_tempo.TempoConfig.REP_MIN_GOOD}s — ${jj_tempo.TempoConfig.REP_MAX_GOOD}s',
          color: const Color(0xFF2B5EA6),
        ),
      ],
      callouts: [
        SkeletonCallout(
          title: 'Tay qua đầu',
          value: '≥ ${jj_arm.ArmExtensionConfig.ELEVATION_GOOD.round()}°',
          color: const Color(0xFFB87320),
          alignment: const Alignment(0.90, -0.45),
          anchor: const Offset(0.25, 0.32),
        ),
        SkeletonCallout(
          title: 'Khuỷu tay',
          value: '≥ ${jj_arm.ArmExtensionConfig.ELBOW_GOOD.round()}°',
          color: const Color(0xFF1B6B52),
          alignment: const Alignment(0.90, -0.04),
          anchor: const Offset(0.30, 0.40),
        ),
        SkeletonCallout(
          title: 'Chân rộng',
          value:
              '≥ ${jj_leg.LegSpreadConfig.SPREAD_GOOD.toStringAsFixed(1)}× vai',
          color: const Color(0xFFB84435),
          alignment: const Alignment(0.90, 0.34),
          anchor: const Offset(0.32, 0.90),
        ),
      ],
      createExercise: createExercise,
    );
  }

  static _ExerciseExperienceSpec _gluteBridgeSpec({
    required ExerciseDefinition definition,
    required int sets,
    required int repsPerSet,
    int? restSeconds,
    required String videoDuration,
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
      videoDuration: videoDuration,
      restSeconds: restSeconds ?? 45,
      targetLabel: 'REP/HIỆP',
      secondsPerUnit: 4,
      posture: SkeletonPosture.lyingFaceUp,
      muscles: definition.targetMuscles,
      tips: definition.setupTips,
      badges: [
        ExerciseIntroBadge(
          title: 'Hạ hông',
          value:
              '≥ ${bridge_speed.SpeedControlConfig.MIN_ECCENTRIC_RATIO.toStringAsFixed(1)}× nhịp nâng',
          color: const Color(0xFF2B5EA6),
        ),
      ],
      callouts: [
        SkeletonCallout(
          title: 'Nâng hông',
          value:
              '${bridge_hip.HipExtensionConfig.GOOD_MIN_ANGLE.round()}° — 175°',
          color: const Color(0xFFB87320),
          alignment: const Alignment(0.90, -0.40),
          anchor: const Offset(0.46, 0.55),
        ),
        SkeletonCallout(
          title: 'Góc gối',
          value:
              '${bridge_knee.KneeAngleConfig.GOOD_MIN.round()}° — ${bridge_knee.KneeAngleConfig.GOOD_MAX.round()}°',
          color: const Color(0xFF1B6B52),
          alignment: const Alignment(0.90, -0.02),
          anchor: const Offset(0.64, 0.66),
        ),
        SkeletonCallout(
          title: 'Đầu cổ',
          value:
              'Nâng < ${(bridge_neck.NeckHeadConfig.HEAD_LIFT_THRESHOLD * 100).round()}% thân',
          color: const Color(0xFFB84435),
          alignment: const Alignment(0.90, 0.34),
          anchor: const Offset(0.20, 0.56),
        ),
      ],
      createExercise: createExercise,
    );
  }

  static _ExerciseExperienceSpec _curlUpSpec({
    required ExerciseDefinition definition,
    required int sets,
    required int repsPerSet,
    int? restSeconds,
    required String videoDuration,
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
      videoDuration: videoDuration,
      restSeconds: restSeconds ?? 45,
      targetLabel: 'REP/HIỆP',
      secondsPerUnit: 4,
      posture: SkeletonPosture.lyingFaceUp,
      muscles: definition.targetMuscles,
      tips: definition.setupTips,
      badges: const [],
      callouts: [
        SkeletonCallout(
          title: 'Biên độ cuộn',
          value:
              '${curl_trunk.TrunkElevationConfig.WARNING_LOW.round()}° — ${curl_trunk.TrunkElevationConfig.WARNING_HIGH.round()}°',
          color: const Color(0xFFB87320),
          alignment: const Alignment(0.90, -0.40),
          anchor: const Offset(0.30, 0.52),
        ),
        SkeletonCallout(
          title: 'Gối giữ cong',
          value:
              '< ${curl_knee.KneeExtensionConfig.WARNING_THRESHOLD.round()}°',
          color: const Color(0xFF1B6B52),
          alignment: const Alignment(0.90, -0.02),
          anchor: const Offset(0.66, 0.67),
        ),
        SkeletonCallout(
          title: 'Không kéo cổ',
          value:
              'Lệch < ${curl_neck.NeckPullingConfig.WARNING_DEVIATION.round()}°',
          color: const Color(0xFFB84435),
          alignment: const Alignment(0.90, 0.34),
          anchor: const Offset(0.22, 0.48),
        ),
      ],
      createExercise: createExercise,
    );
  }
}
