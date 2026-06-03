import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/program_mock.dart';
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
