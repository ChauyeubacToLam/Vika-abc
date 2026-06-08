import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/program_mock.dart';
import '../widgets/progress/period_tabs.dart' show PeriodTab;
import 'recommendation/progression_service.dart';

/// Summary of a completed exercise session, loaded from Supabase.
class PreviousSessionSummary {
  final int formScore;
  final int totalReps;
  final int totalGoodReps;
  final Map<String, int> faultCounts;
  final DateTime completedAt;
  final String? overallDifficulty;

  PreviousSessionSummary({
    required this.formScore,
    required this.totalReps,
    required this.totalGoodReps,
    required this.faultCounts,
    required this.completedAt,
    this.overallDifficulty,
  });

  factory PreviousSessionSummary.fromRow(Map<String, dynamic> row) {
    final faultCountsRow = Map<String, dynamic>.from(
      (row['fault_counts'] as Map?) ?? const <String, dynamic>{},
    );

    return PreviousSessionSummary(
      formScore: (row['form_score'] as num).toInt(),
      totalReps: (row['total_reps'] as num).toInt(),
      totalGoodReps: (row['total_good_reps'] as num).toInt(),
      faultCounts: {
        for (final entry in faultCountsRow.entries)
          entry.key: (entry.value as num).toInt(),
      },
      completedAt: DateTime.parse(row['completed_at'] as String),
      overallDifficulty: row['overall_difficulty'] as String?,
    );
  }
}

/// One active row from `user_pain_areas`, shaped for the Progress-tab pain
/// reporter. [intensity] is the 1..5 self-report (null on rows predating the
/// column); [source] distinguishes a user 'self_reported' area from an
/// interpreter-'confirmed' one; [notes] holds the free-text for an 'other'
/// report.
class PainReport {
  const PainReport({
    required this.region,
    required this.intensity,
    required this.source,
    this.notes,
  });

  final String region;
  final int? intensity;
  final String source;
  final String? notes;
}

/// Persistence layer for exercise sessions + user-level stats.
/// All methods are fire-and-forget where possible — errors are logged
/// but do not interrupt the workout UX.
class SessionPersistence {
  SessionPersistence({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ─── Exercise sessions ─────────────────────────────────────────────

  /// Save a completed exercise session. Fire-and-forget.
  /// Returns session ID on success, null on failure.
  ///
  /// [difficultyRatings] should be one entry per set, null for skipped sets
  /// (e.g. `[heavy, null, medium]` when the user skipped rating set 2).
  /// [overallDifficulty] is captured later via updateSessionDifficulty().
  Future<String?> saveSession({
    required String exerciseId,
    String? recommendationId,
    String? slotName,
    required DateTime startedAt,
    required int formScore,
    required int totalReps,
    required int totalGoodReps,
    required int totalSets,
    required int? calories,
    required String? workoutSessionId,
    required Map<String, int> faultCounts,
    required List<String?> difficultyRatings,
    required List<Map<String, dynamic>> setData,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[Vika] No user, skipping session save');
      return null;
    }

    try {
      final response = await _client
          .from('exercise_sessions')
          .insert({
            'user_id': userId,
            'exercise_id': exerciseId,
            'started_at': startedAt.toUtc().toIso8601String(),
            'form_score': formScore,
            'total_reps': totalReps,
            'total_good_reps': totalGoodReps,
            'total_sets': totalSets,
            'calories': calories,
            'fault_counts': faultCounts,
            'difficulty_ratings': difficultyRatings,
            'set_data': setData,
            'recommendation_id': recommendationId,
            'slot_name': slotName,
            'workout_session_id': workoutSessionId,
          })
          .select('id')
          .single();

      final sessionId = response['id'] as String;
      await RecommendationProgressionService().recordCompletedSession(
        userId: userId,
        sessionId: sessionId,
        exerciseId: exerciseId,
        difficultyRatings: difficultyRatings,
        setData: setData,
      );

      return sessionId;
    } catch (e) {
      debugPrint('[Vika] Failed to save session: $e');
      return null;
    }
  }

  /// Get the most recent session of this exercise for the current user.
  /// Returns null if no previous session or not logged in.
  Future<PreviousSessionSummary?> getPreviousSession(
    String exerciseId,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[Vika] No user, skipping session fetch');
      return null;
    }

    try {
      final response = await _client
          .from('exercise_sessions')
          .select(
              'form_score, total_reps, total_good_reps, fault_counts, completed_at, overall_difficulty')
          .eq('user_id', userId)
          .eq('exercise_id', exerciseId)
          .order('completed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return PreviousSessionSummary.fromRow(response);
    } catch (e) {
      debugPrint('[Vika] Failed to fetch previous session: $e');
      return null;
    }
  }

  /// Get the last [count] sessions for this exercise, ordered oldest-first.
  /// Oldest-first is convenient for trend rendering (sparklines, streak detection).
  /// Returns empty list if no sessions or error.
  Future<List<PreviousSessionSummary>> getSessionHistory(
    String exerciseId, {
    int count = 10,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('exercise_sessions')
          .select(
              'form_score, total_reps, total_good_reps, fault_counts, completed_at, overall_difficulty')
          .eq('user_id', userId)
          .eq('exercise_id', exerciseId)
          .order('completed_at', ascending: false)
          .limit(count);

      // Response is newest-first, reverse to oldest-first for trend rendering.
      final rows = (response as List).reversed.toList();
      return rows
          .map((r) => PreviousSessionSummary.fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Vika] getSessionHistory failed: $e');
      return [];
    }
  }

  /// {weekNumber: {done session indexes}} for a plan, from workout_sessions.
  /// A session counts as done only when completed_at is set.
  Future<Map<int, Set<int>>> completionMapForPlan({
    required String recommendationId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return const {};
    try {
      final rows = await _client
          .from('workout_sessions')
          .select('week_number, session_index')
          .eq('user_id', user.id)
          .eq('recommendation_id', recommendationId)
          .not('completed_at', 'is', null);
      final map = <int, Set<int>>{};
      for (final raw in rows as List) {
        final row = (raw as Map).cast<String, dynamic>();
        final week = (row['week_number'] as num?)?.toInt();
        final session = (row['session_index'] as num?)?.toInt();
        if (week == null || session == null) continue;
        (map[week] ??= <int>{}).add(session);
      }
      return map;
    } catch (e) {
      debugPrint('[SessionPersistence] completion map fetch failed: $e');
      return const {};
    }
  }

  /// Completed workout-level + per-exercise ledger results for a plan.
  ///
  /// Keyed by `(weekNumber, sessionIndex)`. If a user redoes the same planned
  /// session, the latest completed workout session wins.
  Future<PlanLedgerSessionResults> ledgerResultsForPlan({
    required String recommendationId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const {};

    try {
      final workoutRows = await _client
          .from('workout_sessions')
          .select(
            'id, week_number, session_index, completed_at, session_form_score',
          )
          .eq('user_id', userId)
          .eq('recommendation_id', recommendationId)
          .not('completed_at', 'is', null)
          .order('completed_at', ascending: false);

      final latestBySlot = <PlanLedgerSessionKey,
          ({
        String id,
        DateTime completedAt,
        int? sessionFormScore,
      })>{};

      for (final raw in workoutRows as List) {
        final row = (raw as Map).cast<String, dynamic>();
        final id = row['id'] as String?;
        final week = (row['week_number'] as num?)?.toInt();
        final session = (row['session_index'] as num?)?.toInt();
        final completedAt = _dateTimeOrNull(row['completed_at']);
        if (id == null ||
            week == null ||
            session == null ||
            completedAt == null) {
          continue;
        }

        final key = (week, session);
        final existing = latestBySlot[key];
        if (existing == null || completedAt.isAfter(existing.completedAt)) {
          latestBySlot[key] = (
            id: id,
            completedAt: completedAt,
            sessionFormScore: (row['session_form_score'] as num?)?.toInt(),
          );
        }
      }

      final results = <PlanLedgerSessionKey, PlanLedgerSessionResult>{};
      for (final entry in latestBySlot.entries) {
        final exerciseRows = await _client
            .from('exercise_sessions')
            .select('exercise_id, form_score, overall_difficulty')
            .eq('user_id', userId)
            .eq('workout_session_id', entry.value.id);

        final exercises = <String, PlanLedgerExerciseResult>{};
        for (final raw in exerciseRows as List) {
          final row = (raw as Map).cast<String, dynamic>();
          final exerciseId = row['exercise_id'] as String?;
          if (exerciseId == null || exerciseId.isEmpty) continue;
          exercises[exerciseId] = (
            formScore: (row['form_score'] as num?)?.toInt(),
            difficulty: row['overall_difficulty'] as String?,
          );
        }

        results[entry.key] = (
          sessionFormScore: entry.value.sessionFormScore,
          exercises: exercises,
        );
      }

      return results;
    } catch (e) {
      debugPrint('[SessionPersistence] ledger results fetch failed: $e');
      return const {};
    }
  }

  /// MVP workout completion count for v4.4.
  ///
  /// `exercise_sessions` is per exercise, not per workout. Until a real
  /// workout-level table exists, count distinct local completion dates for
  /// exercise rows whose set data belongs to the requested recommendation week.
  Future<int> countCompletedWorkoutDaysForWeek({
    required String recommendationId,
    required int weekNumber,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final rows = await _client
          .from('exercise_sessions')
          .select('completed_at, set_data')
          .eq('user_id', userId)
          .eq('recommendation_id', recommendationId);

      final completedSessionIndexes = <int>{};
      final completedDays = <String>{};
      for (final row in rows as List) {
        final data = row as Map<String, dynamic>;
        if (!_setDataContainsWeek(data['set_data'], weekNumber)) continue;
        completedSessionIndexes.addAll(
          _setDataSessionIndexesForWeek(data['set_data'], weekNumber),
        );
        final completedAt = DateTime.tryParse(
          (data['completed_at'] as String?) ?? '',
        );
        if (completedAt == null) continue;
        final local = completedAt.toLocal();
        completedDays.add('${local.year}-${local.month}-${local.day}');
      }
      if (completedSessionIndexes.isNotEmpty) {
        return completedSessionIndexes.length;
      }
      return completedDays.length;
    } catch (e) {
      debugPrint('[Vika] countCompletedWorkoutDaysForWeek failed: $e');
      return 0;
    }
  }

  /// Exact workout session indexes completed in a recommendation week.
  ///
  /// New workout launches write `week_number` + `session_index` into each
  /// exercise row's `set_data`. Unstarted sessions have no row, so callers
  /// compare these completed indexes against the plan_structure sessions.
  Future<Set<int>> completedWorkoutSessionIndexesForWeek({
    required String recommendationId,
    required int weekNumber,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const <int>{};

    try {
      final rows = await _client
          .from('exercise_sessions')
          .select('set_data')
          .eq('user_id', userId)
          .eq('recommendation_id', recommendationId);

      final completedSessionIndexes = <int>{};
      for (final row in rows as List) {
        final data = row as Map<String, dynamic>;
        completedSessionIndexes.addAll(
          _setDataSessionIndexesForWeek(data['set_data'], weekNumber),
        );
      }
      return completedSessionIndexes;
    } catch (e) {
      debugPrint('[Vika] completedWorkoutSessionIndexesForWeek failed: $e');
      return const <int>{};
    }
  }

  bool _setDataContainsWeek(dynamic rawSetData, int weekNumber) {
    if (rawSetData is! List) return false;
    for (final rawSet in rawSetData) {
      if (rawSet is! Map) continue;
      final value = rawSet['week_number'];
      if (value is num && value.toInt() == weekNumber) return true;
    }
    return false;
  }

  Set<int> _setDataSessionIndexesForWeek(dynamic rawSetData, int weekNumber) {
    final indexes = <int>{};
    if (rawSetData is! List) return indexes;
    for (final rawSet in rawSetData) {
      if (rawSet is! Map) continue;
      final week = rawSet['week_number'];
      final session = rawSet['session_index'];
      if (week is num && week.toInt() == weekNumber && session is num) {
        indexes.add(session.toInt());
      }
    }
    return indexes;
  }

  /// Update overall_difficulty for a session. Called from executive summary
  /// after user taps a difficulty emoji. Fire-and-forget.
  Future<void> updateSessionDifficulty({
    required String sessionId,
    required String difficulty,
  }) async {
    try {
      await _client
          .from('exercise_sessions')
          .update({'overall_difficulty': difficulty}).eq('id', sessionId);
    } catch (e) {
      debugPrint('[Vika] updateSessionDifficulty failed: $e');
    }
  }

  // ─── User-level derived stats ──────────────────────────────────────

  Future<int> currentStreak({bool assumeTodayComplete = false}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final rows = await _client
          .from('workout_sessions')
          .select('completed_at')
          .eq('user_id', userId)
          .not('completed_at', 'is', null)
          .order('completed_at', ascending: false)
          .limit(400);

      final completedAtValues = <DateTime>[];
      for (final raw in rows as List) {
        final row = raw as Map<String, dynamic>;
        final completedAt = _dateTimeOrNull(row['completed_at']);
        if (completedAt != null) {
          completedAtValues.add(completedAt);
        }
      }

      return deriveCurrentStreakForTest(
        completedAtValues,
        assumeTodayComplete: assumeTodayComplete,
      );
    } catch (e) {
      debugPrint('[Vika] currentStreak failed: $e');
      return 0;
    }
  }

  @visibleForTesting
  static int deriveCurrentStreakForTest(
    Iterable<DateTime> completedAtValues, {
    bool assumeTodayComplete = false,
    DateTime? now,
  }) {
    final localNow = (now ?? DateTime.now()).toLocal();
    final today = _LocalDate(localNow.year, localNow.month, localNow.day);
    final completedDates = <_LocalDate>{
      for (final completedAt in completedAtValues)
        _LocalDate.fromDateTime(completedAt.toLocal()),
    };

    if (assumeTodayComplete) {
      completedDates.add(today);
    }

    final yesterday = today.previous;
    _LocalDate anchor;
    if (completedDates.contains(today)) {
      anchor = today;
    } else if (completedDates.contains(yesterday)) {
      anchor = yesterday;
    } else {
      return 0;
    }

    var count = 0;
    var cursor = anchor;
    while (completedDates.contains(cursor)) {
      count += 1;
      cursor = cursor.previous;
    }
    return count;
  }

  /// Profile "Hành trình tính đến hôm nay" lifetime aggregate, computed
  /// client-side from completed workout_sessions. Single round trip; the math
  /// lives in [deriveLifetimeStatsForTest] so it stays unit-testable.
  ///
  ///   sessionCount       — completed sessions
  ///   totalSeconds       — sum of total_duration_seconds (nulls skipped)
  ///   avgForm            — rounded mean session_form_score, null if no scored
  ///                        session
  ///   formDeltaFromStart — latest minus earliest score; null when fewer than
  ///                        3 sessions or fewer than 2 scored sessions
  ///   sessionsThisWeek   — sessions completed within the last 7 days
  Future<
      ({
        int sessionCount,
        int totalSeconds,
        int? avgForm,
        int? formDeltaFromStart,
        int sessionsThisWeek,
      })> lifetimeStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return _emptyLifetimeStats;

    try {
      final rows = await _client
          .from('workout_sessions')
          .select('session_form_score, total_duration_seconds, completed_at')
          .eq('user_id', userId)
          .not('completed_at', 'is', null)
          .order('completed_at', ascending: true);

      final samples =
          <({DateTime completedAt, int? formScore, int? durationSeconds})>[];
      for (final raw in rows as List) {
        final row = (raw as Map).cast<String, dynamic>();
        final completedAt = _dateTimeOrNull(row['completed_at']);
        if (completedAt == null) continue;
        samples.add((
          completedAt: completedAt,
          formScore: (row['session_form_score'] as num?)?.toInt(),
          durationSeconds: (row['total_duration_seconds'] as num?)?.toInt(),
        ));
      }
      return deriveLifetimeStatsForTest(samples);
    } catch (e) {
      debugPrint('[Vika] lifetimeStats failed: $e');
      return _emptyLifetimeStats;
    }
  }

  static const _emptyLifetimeStats = (
    sessionCount: 0,
    totalSeconds: 0,
    avgForm: null,
    formDeltaFromStart: null,
    sessionsThisWeek: 0,
  );

  /// Pure aggregation for [lifetimeStats]. [samples] are completed sessions in
  /// any order; `now` is injectable so the 7-day window is deterministic in
  /// tests.
  @visibleForTesting
  static ({
    int sessionCount,
    int totalSeconds,
    int? avgForm,
    int? formDeltaFromStart,
    int sessionsThisWeek,
  }) deriveLifetimeStatsForTest(
    Iterable<({DateTime completedAt, int? formScore, int? durationSeconds})>
        samples, {
    DateTime? now,
  }) {
    final sorted = [...samples]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final sessionCount = sorted.length;

    var totalSeconds = 0;
    final scores = <int>[];
    for (final s in sorted) {
      if (s.durationSeconds != null) totalSeconds += s.durationSeconds!;
      if (s.formScore != null) scores.add(s.formScore!);
    }

    final avgForm = scores.isEmpty ? null : _roundedMean(scores);
    // A trend only reads as real once there's enough history: 3+ sessions and
    // at least two scored sessions to subtract.
    final formDeltaFromStart = (sessionCount >= 3 && scores.length >= 2)
        ? scores.last - scores.first
        : null;

    final end = now ?? DateTime.now();
    final weekStart = end.subtract(const Duration(days: 7));
    var sessionsThisWeek = 0;
    for (final s in sorted) {
      if (!s.completedAt.isBefore(weekStart) && !s.completedAt.isAfter(end)) {
        sessionsThisWeek++;
      }
    }

    return (
      sessionCount: sessionCount,
      totalSeconds: totalSeconds,
      avgForm: avgForm,
      formDeltaFromStart: formDeltaFromStart,
      sessionsThisWeek: sessionsThisWeek,
    );
  }

  /// Home "FORM 7 NGÀY" vitals summary over a rolling 14-day window.
  ///
  /// Read-only display aggregate — scores are computed and frozen elsewhere.
  /// Reads `session_form_score` — the composite shown to the user.
  ///
  /// Single round trip; the windowing + averaging live in
  /// [deriveHomeFormSummaryForTest] so they stay unit-testable.
  ///
  ///   percent — rounded mean of the current 7-day window, or null when no
  ///             session landed in the last 7 days (cold start)
  ///   delta   — percent minus the rounded mean of the prior week, or null
  ///             unless the prior week holds >= 2 sessions (no baseline -> hide)
  ///   week    — current-window session form scores, oldest-first
  Future<({int? percent, int? delta, List<int> week})> homeFormSummary() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 14));
      final samples = await _sessionFormScoresInWindow(since: since);
      return deriveHomeFormSummaryForTest(samples);
    } catch (e) {
      debugPrint('[Vika] homeFormSummary failed: $e');
      return (percent: null, delta: null, week: const <int>[]);
    }
  }

  /// Completed-session form samples for the current user, oldest-first.
  ///
  /// Single round trip shared by [homeFormSummary] and [progressFormSummary].
  /// Reads `session_form_score` — the composite form number shown to the user
  /// (includes the streak bonus). [since] is an optional lower bound on
  /// `completed_at` (null = all completed sessions). Returns empty when signed
  /// out; throws on a genuine fetch error so callers can log + fall back.
  Future<List<({DateTime completedAt, int formScore})>>
      _sessionFormScoresInWindow({DateTime? since}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    var query = _client
        .from('workout_sessions')
        .select('session_form_score, completed_at')
        .eq('user_id', userId)
        .not('session_form_score', 'is', null);
    if (since != null) {
      query = query.gte('completed_at', since.toUtc().toIso8601String());
    }
    final rows = await query.order('completed_at', ascending: true);

    final samples = <({DateTime completedAt, int formScore})>[];
    for (final raw in rows as List) {
      final row = (raw as Map).cast<String, dynamic>();
      final completedAt = _dateTimeOrNull(row['completed_at']);
      final score = (row['session_form_score'] as num?)?.toInt();
      if (completedAt == null || score == null) continue;
      samples.add((completedAt: completedAt, formScore: score));
    }
    return samples;
  }

  /// Progress tab "ĐIỂM FORM" gauge + "ĐƯỜNG TIẾN BỘ" trend, scoped to a
  /// [PeriodTab] window. Read-only display aggregate — scores are computed
  /// and frozen elsewhere; reads `session_form_score` (the composite shown
  /// to the user).
  ///
  ///   trend — window session form scores, oldest-first (empty = no sessions)
  ///   to    — latest score in the window, or null when empty
  ///   from  — earliest score in the window, or null when empty
  ///   delta — to - from, or null when empty
  Future<({int? to, int? from, int? delta, List<int> trend})>
      progressFormSummary(PeriodTab period) async {
    try {
      final now = DateTime.now();
      final since = switch (period) {
        PeriodTab.week => now.subtract(const Duration(days: 7)),
        PeriodTab.month => now.subtract(const Duration(days: 30)),
        // TODO(wiring): single-program MVP — this returns ALL completed
        // sessions for the user. Scope to the active program
        // (recommendation_id) once multi-program history lands.
        PeriodTab.program => null,
      };
      final samples = await _sessionFormScoresInWindow(since: since);
      return deriveProgressFormSummaryForTest(
        [for (final sample in samples) sample.formScore],
      );
    } catch (e) {
      debugPrint('[Vika] progressFormSummary failed: $e');
      return (to: null, from: null, delta: null, trend: const <int>[]);
    }
  }

  /// Pure aggregation for [progressFormSummary]. [scores] are window session
  /// form scores, oldest-first. Kept separate so the to/from/delta math is
  /// unit-testable without a database.
  @visibleForTesting
  static ({int? to, int? from, int? delta, List<int> trend})
      deriveProgressFormSummaryForTest(List<int> scores) {
    final trend = List<int>.unmodifiable(scores);
    final to = trend.isEmpty ? null : trend.last;
    final from = trend.isEmpty ? null : trend.first;
    final delta = (to != null && from != null) ? to - from : null;
    return (to: to, from: from, delta: delta, trend: trend);
  }

  /// Pure windowing + averaging for [homeFormSummary]. `now` is injectable so
  /// the rolling-window math is deterministic in tests.
  ///
  /// Windows are rolling absolute instants — no timezone handling needed,
  /// the comparisons are independent of UTC vs local:
  ///   current = [now-7d, now]      prior = [now-14d, now-7d)
  @visibleForTesting
  static ({int? percent, int? delta, List<int> week})
      deriveHomeFormSummaryForTest(
    Iterable<({DateTime completedAt, int formScore})> samples, {
    DateTime? now,
  }) {
    final end = now ?? DateTime.now();
    final currentStart = end.subtract(const Duration(days: 7));
    final priorStart = end.subtract(const Duration(days: 14));

    final current = <({DateTime completedAt, int formScore})>[];
    final prior = <int>[];
    for (final sample in samples) {
      final at = sample.completedAt;
      if (!at.isBefore(currentStart) && !at.isAfter(end)) {
        current.add(sample); // [now-7d, now]
      } else if (!at.isBefore(priorStart) && at.isBefore(currentStart)) {
        prior.add(sample.formScore); // [now-14d, now-7d)
      }
    }

    current.sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final week = [for (final sample in current) sample.formScore];

    final percent = week.isEmpty ? null : _roundedMean(week);
    final delta = (percent != null && prior.length >= 2)
        ? percent - _roundedMean(prior)
        : null;

    return (percent: percent, delta: delta, week: week);
  }

  static int _roundedMean(List<int> values) {
    var sum = 0;
    for (final value in values) {
      sum += value;
    }
    return (sum / values.length).round();
  }

  /// Returns list of active body_region strings from user_pain_areas.
  /// Combines onboarding self-reports AND interpreter-confirmed issues.
  /// Empty list = no known pain areas (common before A1 wires onboarding).
  Future<List<String>> getActivePainAreas() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('user_pain_areas')
          .select('body_region')
          .eq('user_id', userId)
          .eq('status', 'active');

      return (response as List)
          .map((row) => (row as Map<String, dynamic>)['body_region'] as String)
          .toList();
    } catch (e) {
      debugPrint('[Vika] getActivePainAreas failed: $e');
      return [];
    }
  }

  /// Active self-reports for the Progress-tab pain reporter — richer than
  /// [getActivePainAreas] (which returns bare regions for plan/interpreter
  /// callers). Carries the reported [PainReport.intensity] (1..5, null on
  /// legacy rows), [PainReport.source] (so a 'confirmed' badge can show), and
  /// [PainReport.notes] (the free-text behind an 'other' report). Empty when
  /// signed out or on error.
  Future<List<PainReport>> getActivePainReports() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('user_pain_areas')
          .select('body_region, intensity, source, notes')
          .eq('user_id', userId)
          .eq('status', 'active');

      return (response as List).map((raw) {
        final row = (raw as Map).cast<String, dynamic>();
        return PainReport(
          region: row['body_region'] as String,
          intensity: (row['intensity'] as num?)?.toInt(),
          source: row['source'] as String,
          notes: row['notes'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('[Vika] getActivePainReports failed: $e');
      return [];
    }
  }

  /// Capture-only self-report of pain in [region] at [intensity] (1..5).
  /// Reaffirm-or-insert, mirroring `OnboardingPersistence._writePainAreas`:
  ///   • an existing active row is refreshed in place — new intensity,
  ///     `last_reaffirmed_at` bumped, `flag_count` incremented, and the source
  ///     is left untouched (a 'confirmed' row stays 'confirmed', never
  ///     downgraded to self-reported).
  ///   • no active row → INSERT a fresh self_reported / active row.
  /// [notes] is persisted only for the free-text 'other' region. Best-effort;
  /// failures are logged, never thrown.
  Future<void> reportPainArea(
    String region,
    int intensity, {
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final now = DateTime.now().toIso8601String();
      final existing = await _client
          .from('user_pain_areas')
          .select('id, flag_count')
          .eq('user_id', userId)
          .eq('body_region', region)
          .eq('status', 'active')
          .maybeSingle();

      if (existing != null) {
        // Reaffirm: read-modify-write flag_count. Not atomic, but a single
        // user tapping one region isn't a contention case. Source is left as
        // is on purpose — do not downgrade a 'confirmed' row.
        final newCount = ((existing['flag_count'] as num?)?.toInt() ?? 1) + 1;
        await _client.from('user_pain_areas').update({
          'intensity': intensity,
          'last_reaffirmed_at': now,
          'flag_count': newCount,
          if (region == 'other' && notes != null) 'notes': notes,
        }).eq('id', existing['id']);
      } else {
        await _client.from('user_pain_areas').insert({
          'user_id': userId,
          'body_region': region,
          'source': 'self_reported',
          'status': 'active',
          'intensity': intensity,
          'first_flagged_at': now,
          'last_reaffirmed_at': now,
          'flag_count': 1,
          if (region == 'other' && notes != null) 'notes': notes,
        });
      }
    } catch (e) {
      debugPrint('[Vika] reportPainArea failed: $e');
    }
  }

  /// Clears a self-report by RESOLVING the active row for [region] — never a
  /// DELETE, so the history (and any interpreter-confirmed origin) is kept.
  /// Best-effort; failures are logged, never thrown.
  Future<void> resolvePainArea(String region) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('user_pain_areas')
          .update({
            'status': 'resolved',
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('body_region', region)
          .eq('status', 'active');
    } catch (e) {
      debugPrint('[Vika] resolvePainArea failed: $e');
    }
  }

  Future<String?> startWorkoutSession({
    required String recommendationId,
    required int weekNumber,
    required int sessionIndex,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('workout_sessions')
          .insert({
            'user_id': userId,
            'recommendation_id': recommendationId,
            'week_number': weekNumber,
            'session_index': sessionIndex,
          })
          .select('id')
          .single();
      return response['id'] as String;
    } catch (e) {
      debugPrint('[Vika] startWorkoutSession failed: $e');
      return null;
    }
  }

  /// Freezes the workout summary after the final exercise.
  ///
  /// [coachNote] stores the summary blob shape
  /// `{ 'trophy': trophy.toJson(), 'coach': coach.toJson() }`.
  Future<void> completeWorkoutSession({
    required String? workoutSessionId,
    required int rawFormScore,
    required int sessionFormScore,
    required int totalReps,
    required int totalGoodReps,
    required int totalCalories,
    required int totalDurationSeconds,
    required Map<String, dynamic> coachNote,
    required String summaryVersion,
  }) async {
    if (workoutSessionId == null || workoutSessionId.isEmpty) {
      debugPrint(
          '[Vika] completeWorkoutSession skipped: missing workoutSessionId');
      return;
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('workout_sessions')
          .update({
            'completed_at': DateTime.now().toUtc().toIso8601String(),
            'raw_form_score': rawFormScore,
            'session_form_score': sessionFormScore,
            'total_reps': totalReps,
            'total_good_reps': totalGoodReps,
            'total_calories': totalCalories,
            'total_duration_seconds': totalDurationSeconds,
            'coach_note': coachNote,
            'summary_version': summaryVersion,
          })
          .eq('id', workoutSessionId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[Vika] completeWorkoutSession failed: $e');
    }
  }

  Future<List<int>> fetchPriorSessionFormsScores(
      String? workoutSessionId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || workoutSessionId == null) return [];

    try {
      final response = await _client
          .from('workout_sessions')
          .select('raw_form_score')
          .eq('user_id', userId)
          .neq('id', workoutSessionId)
          .not('raw_form_score', 'is', null)
          .order('completed_at', ascending: true);

      return (response as List)
          .map((row) => (row as Map<String, dynamic>)['raw_form_score'] as num?)
          .whereType<num>()
          .map((v) => v.toInt())
          .toList();
    } catch (e) {
      debugPrint('[Vika] fetchPriorSessionFormsScores failed: $e');
      return [];
    }
  }

  Future<Map<String, List<int>>> fetchPriorExerciseFormsScores(
      String? workoutSessionId, List<String> sessionIds) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || workoutSessionId == null) return {};

    try {
      final response = await _client
          .from('exercise_sessions')
          .select('exercise_id, form_score')
          .eq('user_id', userId)
          .inFilter('exercise_id', sessionIds)
          .neq('workout_session_id',
              workoutSessionId) // CRITICAL here, see below
          .not('form_score', 'is', null)
          .order('completed_at', ascending: true);

      final map = <String, List<int>>{};
      for (final raw in response as List) {
        final row = raw as Map<String, dynamic>;
        final id = row['exercise_id'] as String;
        final score = (row['form_score'] as num?)?.toInt();
        if (score == null) continue;
        (map[id] ??= <int>[]).add(score);
      }

      return map;
    } catch (e) {
      debugPrint('[Vika] fetchPriorExerciseFormsScores failed: $e');
      return {};
    }
  }
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class _LocalDate {
  const _LocalDate(this.year, this.month, this.day);

  factory _LocalDate.fromDateTime(DateTime value) {
    return _LocalDate(value.year, value.month, value.day);
  }

  final int year;
  final int month;
  final int day;

  _LocalDate get previous {
    final value = DateTime(year, month, day - 1);
    return _LocalDate(value.year, value.month, value.day);
  }

  @override
  bool operator ==(Object other) {
    return other is _LocalDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);
}
