import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vika/services/session_coach_builder.dart';

import '../../exercise/1.Bird Dog/bird_dog.dart';
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
import '../../exercise/wall_push_up/wall_push_up.dart' show WallPushUp;
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
import '../../models/fault_candidate.dart';
import '../../services/analytics_service.dart';
import '../../services/catalog/catalog_source.dart';
import '../../models/post_exercise_data.dart';
import '../../models/workout_session_report.dart';
import '../../services/recommendation/models/plan.dart';
import '../../services/recommendation/progression_service.dart';
import '../../services/recommendation/recommendation_service.dart';
import '../../services/session_summary_builder.dart';
import '../../services/session_trophy_picker.dart';
import '../../utils/exercise_logger.dart';
import '../../utils/orientation_lock.dart';
import 'active_exercise_page.dart';
import 'exercise_launch_args.dart';
import 'exercise_intro_page.dart';
import 'exercise_transition_moment.dart';
import 'rest_screen.dart';
import 'widgets/reviewer_tracking_demo_overlay.dart';
import 'widgets/skeleton_annotation.dart';
import 'workout_summary_screen.dart';
import 'package:vika/services/session_persistence.dart';
import '../../exercise/warrior_1/warrior_one.dart';

class ExerciseExperienceScreen extends StatefulWidget {
  const ExerciseExperienceScreen({
    super.key,
    required this.definition,
    this.workoutSessionId,
    this.catalogExerciseId,
    this.catalogInfo,
    this.prescription,
    this.recommendationId,
    this.weekNumber,
    this.sessionIndex,
    this.slotName,
    this.sequence = const [],
    this.sequenceIndex = 0,
    this.priorReports = const [],
  });

  final ExerciseDefinition definition;
  final String? workoutSessionId;
  final String? catalogExerciseId;
  final ExerciseLaunchCatalogInfo? catalogInfo;
  final VolumePrescription? prescription;
  final String? recommendationId;
  final int? weekNumber;
  final int? sessionIndex;
  final String? slotName;
  final List<ExerciseSequenceItem> sequence;
  final int sequenceIndex;

  /// Reports from earlier exercises in this same workout sequence. The
  /// last entry may have a null `userDifficulty` — the intro page of
  /// this exercise collects that rating before unlocking the auto-start
  /// countdown.
  final List<ExerciseSessionReport> priorReports;

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
  String? _currentSessionId;
  String? _pendingOverallDifficulty;
  Future<String?>? _currentSessionSaveFuture;

  int _currentSet = 1;
  int _currentRepsTarget = 0;
  int? _pendingNextRepsTarget;
  double _userWeightKg = 60;
  DateTime? _startedAt;

  String _coachNote =
      'Buổi này AI sẽ ưu tiên nhịp chậm, form chắc và sự ổn định trong từng rep.';

  // User-level data loaded once at screen init, passed to comparison service.
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

  static const Duration _sessionSaveTransitionTimeout = Duration(seconds: 2);

  /// Returns the next launch args in the sequence with [reports] threaded
  /// forward as priorReports. Returns null when this is the final
  /// exercise in the sequence.
  ExerciseLaunchArgs? _nextInSequenceWith(List<ExerciseSessionReport> reports) {
    final base = ExerciseLaunchArgs(
      definition: widget.definition,
      catalogExerciseId: widget.catalogExerciseId,
      catalogInfo: widget.catalogInfo,
      prescription: widget.prescription,
      recommendationId: widget.recommendationId,
      weekNumber: widget.weekNumber,
      sessionIndex: widget.sessionIndex,
      slotName: widget.slotName,
      sequence: widget.sequence,
      sequenceIndex: widget.sequenceIndex,
      priorReports: widget.priorReports,
      workoutSessionId: widget.workoutSessionId,
    );
    return base.nextInSequence(carryForwardReports: reports);
  }

  bool get _hasNextInSequence =>
      widget.sequenceIndex + 1 < widget.sequence.length;

  String? get _nextExerciseName {
    final nextIdx = widget.sequenceIndex + 1;
    if (nextIdx >= widget.sequence.length) return null;
    return widget.sequence[nextIdx].definition.displayName;
  }

  /// The exercise that just finished before this one, if any. Used to
  /// surface the "rate the previous exercise" block on the intro of
  /// continuation slots.
  ExerciseSessionReport? get _previousReport {
    if (widget.priorReports.isEmpty) return null;
    return widget.priorReports.last;
  }

  void _setFlowState(VoidCallback mutation) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(mutation);
    });
    // Post-frame callbacks don't schedule a frame. On the idle rest->active
    // path (no pose overlay repainting) nothing else would, so force one.
    // ensureVisualUpdate() only schedules when idle, so it's a no-op on the
    // active->rest path that already has frames in flight.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _spec = _ExerciseExperienceSpec.fromDefinition(
      widget.definition,
      prescription: widget.prescription,
      catalogInfo: widget.catalogInfo,
    );
    _currentRepsTarget = _spec.repsPerSet;
    _loadCoachNote();
    _loadUserWeight();
    _loadSessionHistory();
    _loadPainAreas();
  }

  Future<void> _loadUserWeight() async {
    final prefs = await SharedPreferences.getInstance();
    final storedWeight = prefs.getDouble('user_weight');
    if (!mounted || storedWeight == null) return;
    setState(() => _userWeightKg = storedWeight);
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
    // Lifecycle boundary: the user pressed start on the intro and the first set
    // is being prepared. No-op without consent; exercise_id is the catalog id,
    // never anything user-identifying.
    unawaited(
      AnalyticsService.instance.capture(
        'exercise_started',
        props: {'exercise_id': widget.definition.id},
      ),
    );
    setState(() {
      _setLoggers.clear();
      _difficultyLogs.clear();
      _prescribedRepsBySet.clear();
      _fullReport = null;
      _currentSetReport = null;
      _currentSetLogger = null;
      _completedDuration = null;
      _estimatedCalories = null;
      _currentSessionId = null;
      _pendingOverallDifficulty = null;
      _currentSessionSaveFuture = null;
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
    return resolveReportBuilder(widget.definition.id);
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

    // Last set: skip the rest screen entirely and route straight to the
    // cinematic transition moment. Earlier sets still get the rest screen.
    if (_currentSet >= _spec.sets) {
      final completedDuration =
          DateTime.now().difference(_startedAt ?? DateTime.now());
      final calories = _estimateCalories(
        report: report,
        totalDuration: completedDuration,
      );
      _setFlowState(() {
        _currentSetReport = report.sets.last;
        _currentSetLogger = logger;
        _fullReport = report;
        _completedDuration = completedDuration;
        _estimatedCalories = calories;
        _activeExercise = null;
        _phase = _WorkoutFlowPhase.transition;
      });
      _startPersistSession(report);
      return;
    }

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

  void _startPersistSession(PostExerciseData report) {
    final future = _persistSession(report);
    _currentSessionSaveFuture = future;
    unawaited(future);
  }

  Future<String?> _persistSession(PostExerciseData report) async {
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
      totalReps: report.sets.fold(0, (sum, s) => sum + (s.totalReps ?? 0)),
      totalGoodReps: report.sets.fold(0, (sum, s) => sum + (s.goodReps ?? 0)),
      totalSets: report.sets.length,
      calories: _estimatedCalories,
      faultCounts: report.faultCounts,
      difficultyRatings: ratings,
      setData: setData,
      workoutSessionId: widget.workoutSessionId,
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

    return sessionId;
  }

  Future<String?> _sessionIdForTransition() async {
    final readyId = _currentSessionId;
    if (readyId != null) return readyId;

    final saveFuture = _currentSessionSaveFuture;
    if (saveFuture == null) return null;

    try {
      return await saveFuture.timeout(
        _sessionSaveTransitionTimeout,
        onTimeout: () {
          debugPrint(
            '[Vika] Session save still pending after '
            '${_sessionSaveTransitionTimeout.inSeconds}s; '
            'continuing transition without session id',
          );
          return null;
        },
      );
    } catch (e) {
      debugPrint('[Vika] Session save unavailable for transition: $e');
      return null;
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
      final completedDuration =
          DateTime.now().difference(_startedAt ?? DateTime.now());
      final calories = _estimateCalories(
        report: report,
        totalDuration: completedDuration,
      );

      _setFlowState(() {
        _fullReport = report;
        _completedDuration = completedDuration;
        _estimatedCalories = calories;
        _activeExercise = null;
        _phase = _WorkoutFlowPhase.transition;
      });

      if (!_isAssessment) {
        _startPersistSession(report);
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

  /// Called when the 3.5-sec transition cinematic finishes auto-advancing.
  /// Builds the [ExerciseSessionReport] for THIS exercise, appends it
  /// onto `widget.priorReports`, and routes to either the next exercise
  /// or the workout-wide summary screen.
  Future<void> _handleTransitionComplete() async {
    final report = _fullReport;
    if (report == null) {
      // Defensive: shouldn't happen, but bail to home cleanly.
      Navigator.of(context).pop({'completed': true});
      return;
    }

    // Lifecycle boundary: every completed exercise (all sets done) converges
    // here once the transition cinematic finishes. No-op without consent; this
    // only emits an event — it does not touch the session data being written.
    unawaited(
      AnalyticsService.instance.capture(
        'exercise_completed',
        props: {'exercise_id': widget.definition.id},
      ),
    );

    final sessionId = await _sessionIdForTransition();
    if (!mounted) return;

    final newEntry = ExerciseSessionReport(
      definition: widget.definition,
      exerciseKey: _sessionExerciseId,
      report: report,
      duration: _completedDuration ?? Duration.zero,
      calories: _estimatedCalories ?? 0,
      sessionId: sessionId,
      // userDifficulty is collected on the NEXT exercise's intro (or on
      // the workout summary for the last exercise).
    );
    final accumulated = [...widget.priorReports, newEntry];

    if (_hasNextInSequence) {
      final next = _nextInSequenceWith(accumulated);
      Navigator.of(context).pop({'completed': true, 'next': next});
    } else {
      // Final exercise — push the workout summary on top, then when the
      // user dismisses it, pop back to the caller with `completed: true`.
      //
      // IMPORTANT: We `pushReplacement` so this experience screen state
      // is disposed once the summary is up. That means the callbacks
      // below MUST NOT close over `this.context` (which becomes invalid
      // after dispose) — instead, the summary screen's own BuildContext
      // is used to pop.
      final streakWeeks = await SessionPersistence().currentStreak(
        // Standalone runs never write a workout_sessions row, so don't assume
        // this week is active off a session that won't persist there. Plan
        // runs do persist, so the assumption is honest for them.
        assumeTodayComplete: widget.workoutSessionId != null,
      );
      if (!mounted) return;

      final sessionSummary = SessionSummaryBuilder.build(
        accumulated,
        streakWeeks,
      );

      // These reads exclude the current workout_session_id and return
      // oldest-first form histories for the trophy picker.
      final priorSessionForms =
          await SessionPersistence().fetchPriorSessionFormsScores(
        widget.workoutSessionId,
      );
      final exerciseIds =
          accumulated.map((r) => r.exerciseKey).toSet().toList();
      final priorExerciseForms =
          await SessionPersistence().fetchPriorExerciseFormsScores(
        widget.workoutSessionId,
        exerciseIds,
        // Standalone has no workout_session_id anchor, so exclude this run's
        // own exercise_sessions row(s) by id instead — otherwise the current
        // run leaks into its own "prior" history and masks a real PB.
        excludeExerciseSessionIds: widget.workoutSessionId == null
            ? [
                for (final r in accumulated)
                  if (r.sessionId != null) r.sessionId!
              ]
            : const [],
      );

      final candidates = <FaultCandidate>[];
      var lowestFormScore = accumulated.first.formScore;
      for (final r in accumulated) {
        lowestFormScore = min(r.formScore, lowestFormScore);
        final builder = resolveReportBuilder(r.definition.id).builder;
        candidates.addAll(
          builder.buildFaultCandidates(
            exerciseId: r.exerciseKey,
            exerciseName: r.exerciseName,
            exerciseFormScore: r.formScore,
            faultCounts: r.report.faultCounts,
            totalReps: r.report.isSecondBased
                ? (r.report.totalSeconds ?? 0).round()
                : (r.totalReps ?? 0),
            userPainAreas: _painAreas,
          ),
        );
      }

      var trophy = SessionTrophyPicker.pick(
        reports: accumulated,
        sessionRawFormScore: sessionSummary.rawFormScore,
        streakWeeks: streakWeeks,
        priorSessionForms: priorSessionForms,
        priorExerciseForms: priorExerciseForms,
      );
      if (sessionSummary.rawFormScore == 0) {
        trophy = const Trophy(
          tier: TrophyTier.showedUp,
          value: '1',
          label: 'Có mặt là đẳng cấp rồi',
          tag: 'CÓ MẶT',
        );
      }
      final coach = SessionCoachBuilder.build(
        candidates: candidates,
        lowestFormScore: lowestFormScore,
        trophy: trophy,
      );

      await SessionPersistence().completeWorkoutSession(
        workoutSessionId: widget.workoutSessionId,
        rawFormScore: sessionSummary.rawFormScore,
        sessionFormScore: sessionSummary.sessionFormScore,
        totalReps: accumulated.fold<int>(0, (s, r) => s + (r.totalReps ?? 0)),
        totalGoodReps:
            accumulated.fold<int>(0, (s, r) => s + (r.goodReps ?? 0)),
        totalCalories: _aggregateCalories(accumulated),
        totalDurationSeconds: _aggregateDuration(accumulated).inSeconds,
        coachNote: {'trophy': trophy.toJson(), 'coach': coach.toJson()},
        summaryVersion: 'summary-v1',
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (summaryContext) => WorkoutSummaryScreen(
            reports: accumulated,
            sessionSummary: sessionSummary,
            totalDuration: _aggregateDuration(accumulated),
            totalCalories: _aggregateCalories(accumulated),
            trophy: trophy,
            coach: coach,
            onLastExerciseDifficulty: (d) {
              // Overall difficulty for the last exercise persists to its own
              // exercise_sessions row via updateSessionDifficulty (queued in
              // _pendingOverallDifficulty if the rating beats the save).
              _handleOverallDifficulty(d);
            },
            onSessionRpe: (_) {
              // TODO(wiring): persist session-level RPE separately.
            },
            onDone: () => Navigator.of(summaryContext).pop({'completed': true}),
          ),
        ),
      );
    }
  }

  Duration _aggregateDuration(List<ExerciseSessionReport> reports) {
    var total = Duration.zero;
    for (final r in reports) {
      total += r.duration;
    }
    return total;
  }

  int _aggregateCalories(List<ExerciseSessionReport> reports) {
    return reports.fold(0, (s, r) => s + r.calories);
  }

  /// Called when the user picks a difficulty for the *previous* exercise
  /// on this exercise's intro page (or the last exercise's difficulty on
  /// the summary screen).
  void _handlePreviousExerciseDifficulty(String difficulty) {
    final prev = _previousReport;
    if (prev == null) return;
    prev.userDifficulty = difficulty;
    final prevId = prev.sessionId;
    if (prevId == null) {
      debugPrint(
        '[Vika] Cannot persist previous exercise difficulty; session id missing',
      );
      return;
    }
    SessionPersistence().updateSessionDifficulty(
      sessionId: prevId,
      difficulty: difficulty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (_phase) {
      _WorkoutFlowPhase.active => const Color(0xFF15110D),
      _WorkoutFlowPhase.transition => const Color(0xFF15110D),
      _ => const Color(0xFFF0EDE6),
    };
    final prev = _previousReport;
    final phaseBody = switch (_phase) {
      _WorkoutFlowPhase.intro => ExerciseIntroPage(
          title: widget.definition.displayName,
          difficulty: widget.definition.difficulty,
          totalSets: _spec.sets,
          repsPerSet: _spec.repsPerSet,
          videoAsset: widget.definition.videoAsset,
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
          previousExerciseName: prev?.exerciseName,
          previousExerciseFormScore: prev?.formScore,
          previousExerciseIssueQuestion: prev?.report.issueQuestion,
          onPreviousDifficulty:
              prev != null ? _handlePreviousExerciseDifficulty : null,
          onStart: _beginWorkout,
          onReviewerDemoHold: (widget.definition.id == 'squat' ||
                  widget.definition.id == 'squat_assessment')
              ? () => ReviewerTrackingDemoOverlay.show(context)
              : null,
          onBack: () => Navigator.of(context).pop(),
        ),
      _WorkoutFlowPhase.active => ActiveExercisePage(
          definition: widget.definition,
          exercise: _activeExercise!,
          currentSet: _currentSet,
          totalSets: _spec.sets,
          totalReps: _currentRepsTarget,
          isTimeBased: _spec.timeBased,
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
          exerciseName: widget.definition.displayName,
          setLogger: _currentSetLogger,
          onNext: _handleSummaryNext,
          previousSession: _sessionHistory,
          onDifficultyAnswer: _handleDifficultyAnswer,
        ),
      _WorkoutFlowPhase.transition => ExerciseTransitionMoment(
          exerciseName: widget.definition.displayName,
          formScore: _fullReport?.formScore ?? 0,
          setResults: _fullReport?.sets ?? const [],
          timeBased: _fullReport?.isSecondBased ?? false,
          nextExerciseName: _hasNextInSequence
              ? 'Bài tiếp theo · ${_nextExerciseName ?? ''}'
              : 'Tổng kết buổi tập',
          onComplete: _handleTransitionComplete,
        ),
    };

    return Scaffold(
      backgroundColor: backgroundColor,
      body: phaseBody,
    );
  }
}

enum _WorkoutFlowPhase { intro, active, rest, transition }

// Never-crash guard for a MISSING catalog entry (a data error — a launch asked
// for an id with no row in exercise_catalog.json). These are NOT per-exercise
// defaults; real volume always comes from the catalog. _resolveVolume logs in
// debug whenever it falls back to these.
const int kFallbackSets = 3;
const int kFallbackReps = 8;
const int kFallbackSeconds = 30;

@visibleForTesting
({
  int sets,
  int targetPerSet,
  String targetLabel,
  double secondsPerUnit,
  bool timeBased,
  ExerciseBase exercise,
}) debugBuildExerciseExperienceSpec(
  ExerciseDefinition definition, {
  VolumePrescription? prescription,
  ExerciseLaunchCatalogInfo? catalogInfo,
}) {
  final spec = _ExerciseExperienceSpec.fromDefinition(
    definition,
    prescription: prescription,
    catalogInfo: catalogInfo,
  );
  return (
    sets: spec.sets,
    targetPerSet: spec.repsPerSet,
    targetLabel: spec.targetLabel,
    secondsPerUnit: spec.secondsPerUnit,
    timeBased: spec.timeBased,
    exercise: spec.createExercise(spec.repsPerSet),
  );
}

class _ExerciseExperienceSpec {
  const _ExerciseExperienceSpec({
    required this.sets,
    required this.repsPerSet,
    required this.restSeconds,
    required this.targetLabel,
    required this.secondsPerUnit,
    required this.posture,
    required this.muscles,
    required this.tips,
    required this.badges,
    required this.callouts,
    required this.createExercise,
    this.timeBased = false,
  });

  final int sets;
  final int repsPerSet;
  final int restSeconds;
  final String targetLabel;
  final double secondsPerUnit;
  final SkeletonPosture posture;
  final List<String> muscles;
  final List<String> tips;
  final List<ExerciseIntroBadge> badges;
  final List<SkeletonCallout> callouts;
  final ExerciseBase Function(int repsPerSet) createExercise;
  final bool timeBased;

  factory _ExerciseExperienceSpec.fromDefinition(
    ExerciseDefinition definition, {
    VolumePrescription? prescription,
    ExerciseLaunchCatalogInfo? catalogInfo,
  }) {
    final overrideRest = prescription?.restSeconds;

    // Resolve volume ONCE, precedence: prescription > catalog > definition
    // default. `target` is the per-set rep/second goal — the displayed value
    // AND the scoring denominator — so it is floored at 1 and can never be 0.
    final resolvedCatalogInfo =
        catalogInfo ?? CatalogSource.instance.lookup(definition.id);
    final volume =
        _resolveVolume(definition, prescription, resolvedCatalogInfo);
    final sets = volume.sets;
    final target = volume.target;
    final isHold = volume.isHold;

    switch (definition.id) {
      case 'squat_assessment':
        return _ExerciseExperienceSpec(
          sets: 1,
          repsPerSet: 5,
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
          createExercise: (repsPerSet) => WallPushUp(maxRep: repsPerSet),
        );
      case 'warrior_one_assessment':
        return _generic(
          definition: definition,
          sets: 1,
          repsPerSet: 1, // một lần giữ để đánh giá
          restSeconds: overrideRest,
          createExercise: (repsPerSet) => WarriorOne(maxHolds: repsPerSet),
        );
      case 'seated_forward_fold_assessment':
        return _generic(
          definition: definition,
          sets: 1,
          repsPerSet: 30, // giữ 30 giây để đánh giá
          restSeconds: overrideRest,
          targetLabel: 'GIÂY/HIỆP',
          secondsPerUnit: 1,
          timeBased: true,
          createExercise: (repsPerSet) =>
              definition.createExercise(seconds: repsPerSet),
        );
      case 'squat':
        return _ExerciseExperienceSpec(
          sets: sets,
          repsPerSet: target,
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
          sets: sets,
          repsPerSet: target,
          restSeconds: overrideRest,
          createExercise: (repsPerSet) => Lunge(maxRep: repsPerSet),
        );
      case 'push_up':
        return _pushUpSpec(
          definition: definition,
          sets: sets,
          repsPerSet: target,
          restSeconds: overrideRest,
          createExercise: (repsPerSet) => PushUp(maxRep: repsPerSet),
        );
      case 'plank':
        return _plankSpec(
          definition: definition,
          sets: sets,
          repsPerSet: target,
          restSeconds: overrideRest,
          createExercise: (repsPerSet) => Plank(maxRep: repsPerSet),
        );
      case 'jumping_jack':
        return _jumpingJackSpec(
          definition: definition,
          sets: sets,
          repsPerSet: target,
          restSeconds: overrideRest,
          createExercise: (repsPerSet) => JumpingJack(maxRep: repsPerSet),
        );
      case 'warrior_one':
        return _generic(
          definition: definition,
          sets: sets,
          repsPerSet: target, // 2 lần giữ = 2 bên
          restSeconds: overrideRest,
          createExercise: (repsPerSet) => WarriorOne(maxHolds: repsPerSet),
        );
      case 'glute_bridge':
        return _gluteBridgeSpec(
          definition: definition,
          sets: sets,
          repsPerSet: target,
          restSeconds: overrideRest,
          createExercise: (repsPerSet) => GluteBridge(maxRep: repsPerSet),
        );
      case 'curl_up':
        return _curlUpSpec(
          definition: definition,
          sets: sets,
          repsPerSet: target,
          restSeconds: overrideRest,
          createExercise: (repsPerSet) => CurlUp(maxRep: repsPerSet),
        );
      case 'bird__dog':
        return _generic(
          definition: definition,
          sets: sets,
          repsPerSet: target,
          restSeconds: overrideRest,
          createExercise: (repsPerSet) => BirdDog(maxRep: repsPerSet),
        );
      default:
        // isHold comes from the DEFINITION's declared target type, not from
        // catalog seconds. Rep-type and hold-type both feed the single
        // resolved `target` into createExercise — never a null target.
        return _generic(
          definition: definition,
          sets: sets,
          repsPerSet: target,
          restSeconds: overrideRest,
          targetLabel: isHold ? 'GIÂY/HIỆP' : 'REP/HIỆP',
          secondsPerUnit: isHold ? 1 : 4,
          timeBased: isHold,
          createExercise: (targetPerSet) => definition.createExercise(
            reps: isHold ? null : targetPerSet,
            seconds: isHold ? targetPerSet : null,
          ),
        );
    }
  }

  /// Resolves (sets, target, isHold) for a launch from the CATALOG (+ any plan
  /// prescription), never from the definition. Precedence is
  /// prescription > catalog > floor fallback. Sets, type, and target all come
  /// from the catalog entry; `target` is the per-set rep/second goal AND the
  /// scoring denominator, so it is hard-floored at 1 and asserted positive — it
  /// can never be 0.
  static ({int sets, int target, bool isHold}) _resolveVolume(
    ExerciseDefinition definition,
    VolumePrescription? prescription,
    ExerciseLaunchCatalogInfo? catalogInfo,
  ) {
    final catalogSeconds = catalogInfo?.baseSeconds;
    final catalogReps = catalogInfo?.baseReps;
    final rawSets =
        prescription?.sets ?? catalogInfo?.baseSets ?? kFallbackSets;
    // A plan may explicitly override the catalog modality. If neither source
    // is available (for example a direct library launch), the definition still
    // carries the modality so second-based exercises never fall back to reps.
    final isHold = prescription?.seconds != null
        ? true
        : prescription?.reps != null
            ? false
            : catalogSeconds != null
                ? true
                : catalogReps != null
                    ? false
                    : definition.targetType == ExerciseTargetType.seconds;
    final resolved = isHold
        ? (prescription?.seconds ?? catalogSeconds)
        : (prescription?.reps ?? catalogReps);
    final sets = rawSets < 1 ? 1 : rawSets;
    // Floor guards a missing or zero catalog target (a data error); the
    // displayed target / scoring denominator is never 0.
    final target = (resolved == null || resolved < 1)
        ? (isHold ? kFallbackSeconds : kFallbackReps)
        : resolved;
    assert(target > 0);
    assert(() {
      if (catalogInfo == null && prescription == null) {
        debugPrint(
          '[Vika] _resolveVolume: no catalog entry or prescription for '
          '"${definition.id}" — using floor fallback. Missing catalog asset row?',
        );
      }
      return true;
    }());
    return (sets: sets, target: target, isHold: isHold);
  }

  static _ExerciseExperienceSpec _generic({
    required ExerciseDefinition definition,
    int sets = 3,
    required int repsPerSet,
    int? restSeconds,
    String targetLabel = 'REP/HIỆP',
    double secondsPerUnit = 4,
    bool timeBased = false,
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
      restSeconds: restSeconds ?? 45,
      targetLabel: targetLabel,
      secondsPerUnit: secondsPerUnit,
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
      timeBased: timeBased,
    );
  }

  static _ExerciseExperienceSpec _lungeSpec({
    required ExerciseDefinition definition,
    required int sets,
    required int repsPerSet,
    int? restSeconds,
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
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
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
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
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
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
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
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
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
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
    required ExerciseBase Function(int repsPerSet) createExercise,
  }) {
    return _ExerciseExperienceSpec(
      sets: sets,
      repsPerSet: repsPerSet,
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
