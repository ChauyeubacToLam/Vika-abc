import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/milestones.dart';
import '../data/program_mock.dart';
import '../exercise/report_builder_registry.dart';
import '../models/pain_regions.dart';
import '../widgets/progress/period_tabs.dart'
    show PeriodTab, FormTrendDirection;
import 'recommendation/progression_service.dart';
import 'streak_tier.dart';

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

// ─── Progress tab: ranked insights (BÀI TẬP NỔI BẬT) ──────────────────
//
// Per-exercise improvement ranking. Each qualifying exercise contributes
// ONE headline, picked from an ordinal tier ladder (pain-fault → form →
// generic-fault). The headline carries a Theil-Sen slope (oriented so
// positive = improvement) plus the fitted start/end values for the card.

/// Which signal a ranked-insight headline is built from. Tier order is the
/// selection priority AND the cross-exercise sort rank ([Enum.index]):
/// pain (0) → form (1) → generic (2).
enum InsightTier { pain, form, generic }

/// One per-exercise session row feeding [SessionPersistence.deriveRankedInsightsForTest].
/// The deriver groups these by [exerciseId] in input order, so callers must
/// pass them oldest-first (the x-axis for every slope is the session order
/// index 0,1,2… — never a timestamp, which would distort across gaps).
typedef RankInsightSession = ({
  String exerciseId,
  int formScore,
  Map<String, int> faultCounts,
  int totalReps,
});

/// Per-exercise metadata pulled from the exercise's report builder.
/// [painToFaultMap] maps a user pain area → the fault keys this exercise
/// tracks for it; [praiseMetricNames] maps a fault key → its VN label. An
/// unregistered exercise (GenericReportBuilder) supplies empty maps, so it
/// can only ever produce a FORM headline (no labelled fault).
typedef RankInsightMeta = ({
  Map<String, List<String>> painToFaultMap,
  Map<String, String> praiseMetricNames,
});

/// One ranked-insight headline for a BÀI TẬP NỔI BẬT card. Pure data — the
/// screen maps it to an `ExerciseInsightMock` (resolving the display name and
/// formatting the improvement copy). For the form tier [faultKey]/[metricLabel]
/// are null and [fromValue]/[toValue] are fitted form scores; for fault tiers
/// they are the fitted fault rate as a % of reps (so [fromValue] > [toValue]).
///
/// [series] is the per-session metric, oldest-first, that backs the card's bar
/// chart — raw form scores for the form tier, rounded fault rate % for fault
/// tiers. [lowerIsBetter] is true for fault tiers (a falling value is progress)
/// so the chart can orient bars as a climb regardless of metric polarity.
typedef RankInsightHeadline = ({
  String exerciseId,
  InsightTier tier,
  String? faultKey,
  String? metricLabel,
  double slopeMagnitude,
  int fromValue,
  int toValue,
  List<int> series,
  bool lowerIsBetter,
});

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

  /// Current streak as consecutive ACTIVE WEEKS — weeks (ISO, local tz) with
  /// >= 1 completed workout session, counting back from this week (or last
  /// week if this one is still empty). [assumeTodayComplete] marks THIS WEEK
  /// active (used at save time, when the just-finished session may not be
  /// persisted yet). Surfaces render the result via [streakTierLabel].
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

  /// Consecutive active WEEKS up to now. Each completion is bucketed by the
  /// Monday of its LOCAL ISO week; the run is anchored at this week if active,
  /// else last week, else 0. [assumeTodayComplete] marks THIS WEEK active.
  /// A week with even one session keeps the run alive (a single rest day — or
  /// rest days — never breaks it); a fully empty week ends it.
  @visibleForTesting
  static int deriveCurrentStreakForTest(
    Iterable<DateTime> completedAtValues, {
    bool assumeTodayComplete = false,
    DateTime? now,
  }) {
    final localNow = (now ?? DateTime.now()).toLocal();
    final thisWeek = _mondayOf(
      _LocalDate(localNow.year, localNow.month, localNow.day),
    );
    final activeWeeks = <_LocalDate>{
      for (final completedAt in completedAtValues)
        _mondayOf(_LocalDate.fromDateTime(completedAt.toLocal())),
    };

    if (assumeTodayComplete) {
      activeWeeks.add(thisWeek);
    }

    final lastWeek = thisWeek.previousWeek;
    _LocalDate anchor;
    if (activeWeeks.contains(thisWeek)) {
      anchor = thisWeek;
    } else if (activeWeeks.contains(lastWeek)) {
      anchor = lastWeek;
    } else {
      return 0;
    }

    var count = 0;
    var cursor = anchor;
    while (activeWeeks.contains(cursor)) {
      count += 1;
      cursor = cursor.previousWeek;
    }
    return count;
  }

  /// Weekly activity from the user's FIRST active week up to the current week
  /// (capped at [weekCount]) for the Progress "Chuỗi" strip: one bool per week,
  /// oldest-first, last entry = the current week. A week is true when it has
  /// >= 1 completed session. Empty (`[]`) when there is no activity yet. Single
  /// round trip; the windowing lives in [deriveStreakWeekBarsForTest].
  ///
  /// Shares the SAME active-week definition + ISO-week bucketing as
  /// [currentStreak], so the trailing run of filled cells equals the current
  /// streak (when this week is active — the same one-week grace [currentStreak]
  /// allows for an as-yet-empty current week is the only divergence).
  Future<List<bool>> streakWeekBars({int weekCount = 12}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const <bool>[];

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
        final row = (raw as Map).cast<String, dynamic>();
        final completedAt = _dateTimeOrNull(row['completed_at']);
        if (completedAt != null) completedAtValues.add(completedAt);
      }
      return deriveStreakWeekBarsForTest(completedAtValues,
          weekCount: weekCount);
    } catch (e) {
      debugPrint('[Vika] streakWeekBars failed: $e');
      return const <bool>[];
    }
  }

  /// Pure week-bucketing for [streakWeekBars]. Buckets each completion by its
  /// local ISO-week Monday (the SAME [_mondayOf] / [_LocalDate] math
  /// [deriveCurrentStreakForTest] uses — not duplicated), then emits one bool
  /// per week from the user's FIRST active week up to the current week,
  /// oldest-first (last = current week). `now` is injectable for tests.
  ///
  /// The window is ANCHORED at the first active week and grows forward, capped
  /// at [weekCount]: the leading edge is max(firstActiveWeek, currentWeek -
  /// (weekCount-1)). A brand-new user gets a short, honest strip (1..weekCount
  /// cells) instead of a wall of dead pre-join cells; a veteran gets a rolling
  /// last-[weekCount]-weeks window. Empty cells only ever represent rest weeks
  /// the user actually lived through. Returns `[]` when there is no activity.
  ///
  /// This is the gold-standard convention (Strava / Duolingo / Apple Fitness):
  /// anchor at first activity, never pad before the user joined.
  @visibleForTesting
  static List<bool> deriveStreakWeekBarsForTest(
    Iterable<DateTime> completedAtValues, {
    int weekCount = 12,
    DateTime? now,
  }) {
    final localNow = (now ?? DateTime.now()).toLocal();
    final activeWeeks = <_LocalDate>{
      for (final completedAt in completedAtValues)
        _mondayOf(_LocalDate.fromDateTime(completedAt.toLocal())),
    };
    if (activeWeeks.isEmpty) return const <bool>[];

    // Earliest active week — the anchor we stop walking back at.
    var firstWeek = activeWeeks.first;
    for (final w in activeWeeks) {
      if (DateTime(w.year, w.month, w.day)
          .isBefore(DateTime(firstWeek.year, firstWeek.month, firstWeek.day))) {
        firstWeek = w;
      }
    }

    // Walk back from the current week, stopping once we include the first
    // active week (anchor) or hit the [weekCount] cap, then reverse to
    // oldest-first (last = current week).
    final bars = <bool>[];
    var cursor = _mondayOf(
      _LocalDate(localNow.year, localNow.month, localNow.day),
    );
    for (var i = 0; i < weekCount; i++) {
      bars.add(activeWeeks.contains(cursor));
      if (cursor == firstWeek) break; // reached the anchor — earlier = pre-join
      cursor = cursor.previousWeek;
    }
    return bars.reversed.toList();
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
  ///             unless the prior week holds >= 3 sessions (no baseline -> hide)
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
  ///   average    — rounded mean of the window scores (the gauge headline),
  ///                or null when the window is empty
  ///   direction  — Theil-Sen slope direction over the window for the gauge's
  ///                trend chip; [FormTrendDirection.none] until >= 3 sessions
  ///   trend      — window session form scores, oldest-first (empty = none)
  ///   trendDates — the completed_at of each trend point, parallel to [trend]
  ///                (UTC; call .toLocal() before formatting axis labels)
  ///   fact       — factual trajectory one-liner for the gauge ('' when empty)
  Future<
      ({
        int? average,
        FormTrendDirection direction,
        List<int> trend,
        List<DateTime> trendDates,
        String fact,
      })> progressFormSummary(PeriodTab period) async {
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
      final scores = [for (final sample in samples) sample.formScore];
      final base = deriveProgressFormSummaryForTest(scores);
      // Theil-Sen fitted rise across the span (slope · span) drives the
      // trajectory sentence's granularity; null below the 3-session baseline,
      // matching the gauge gate. Same fit the chip's [direction] reads.
      final netChange = scores.length >= 3
          ? (_theilSen([for (final v in scores) v.toDouble()]).slope *
                  (scores.length - 1))
              .round()
          : null;
      return (
        average: base.average,
        direction: base.direction,
        trend: base.trend,
        trendDates: [for (final sample in samples) sample.completedAt],
        fact: deriveTrajectoryFactForTest(
          trend: base.trend,
          netChange: netChange,
          average: base.average,
        ),
      );
    } catch (e) {
      debugPrint('[Vika] progressFormSummary failed: $e');
      return (
        average: null,
        direction: FormTrendDirection.none,
        trend: const <int>[],
        trendDates: const <DateTime>[],
        fact: '',
      );
    }
  }

  /// Theil-Sen slope (form points per session) the window must clear, in
  /// either direction, for the gauge trend chip to read as rising/falling
  /// rather than holding steady. Below this magnitude the slope reads as noise
  /// and the direction is [FormTrendDirection.flat]. Tunable.
  static const double kFormTrendSlopeThreshold = 0.5;

  /// Pure aggregation for [progressFormSummary]. [scores] are window session
  /// form scores, oldest-first. Kept separate so the average + slope-direction
  /// math is unit-testable without a database.
  ///
  /// Progressive reveal: [average] (rounded window mean) is the gauge headline
  /// and shows at >= 1 session. [direction] reads the Theil-Sen slope over the
  /// window (x = session index 0..n-1) but only past the same 3-session
  /// baseline the rest of the Progress tab uses — below that it is
  /// [FormTrendDirection.none] and the gauge hides the trend chip.
  @visibleForTesting
  static ({int? average, FormTrendDirection direction, List<int> trend})
      deriveProgressFormSummaryForTest(List<int> scores) {
    final trend = List<int>.unmodifiable(scores);
    final average = trend.isEmpty ? null : _roundedMean(trend);
    final FormTrendDirection direction;
    if (trend.length < 3) {
      direction = FormTrendDirection.none; // no baseline yet
    } else {
      final slope = _theilSen([for (final v in trend) v.toDouble()]).slope;
      if (slope > kFormTrendSlopeThreshold) {
        direction = FormTrendDirection.up;
      } else if (slope < -kFormTrendSlopeThreshold) {
        direction = FormTrendDirection.down;
      } else {
        direction = FormTrendDirection.flat;
      }
    }
    return (average: average, direction: direction, trend: trend);
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
    // Progressive reveal: a week-over-week delta only reads as real once the
    // prior week holds >= 3 sessions (same policy as the Progress tab).
    final delta = (percent != null && prior.length >= 3)
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

  // ─── Progress tab: weekly summary band (TUẦN NÀY MỘT NHÌN) ──────────

  /// Rolling 7-day summary for the Progress-tab weekly band: sessions
  /// completed, total active seconds, and mean form. Single round trip;
  /// the windowing + deltas live in [deriveWeeklySummaryForTest].
  ///
  ///   sessions       — completed sessions in [now-7d, now]
  ///   totalSeconds   — sum of total_duration_seconds in the window
  ///   avgForm        — rounded mean session_form_score, null if none scored
  ///   sessionsDelta  — vs the prior 7-day window, or null unless that prior
  ///   secondsDelta     window holds >= 3 sessions (no baseline -> hide notes)
  ///   avgFormDelta
  Future<
      ({
        int sessions,
        int totalSeconds,
        int? avgForm,
        int? sessionsDelta,
        int? secondsDelta,
        int? avgFormDelta,
      })> weeklySummary() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return _emptyWeeklySummary;

    try {
      final since = DateTime.now().subtract(const Duration(days: 14));
      final rows = await _client
          .from('workout_sessions')
          .select('session_form_score, total_duration_seconds, completed_at')
          .eq('user_id', userId)
          .not('completed_at', 'is', null)
          .gte('completed_at', since.toUtc().toIso8601String())
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
      return deriveWeeklySummaryForTest(samples);
    } catch (e) {
      debugPrint('[Vika] weeklySummary failed: $e');
      return _emptyWeeklySummary;
    }
  }

  static const _emptyWeeklySummary = (
    sessions: 0,
    totalSeconds: 0,
    avgForm: null,
    sessionsDelta: null,
    secondsDelta: null,
    avgFormDelta: null,
  );

  /// Pure windowing for [weeklySummary]. `now` is injectable so the rolling
  /// windows are deterministic in tests.
  ///   current = [now-7d, now]      prior = [now-14d, now-7d)
  @visibleForTesting
  static ({
    int sessions,
    int totalSeconds,
    int? avgForm,
    int? sessionsDelta,
    int? secondsDelta,
    int? avgFormDelta,
  }) deriveWeeklySummaryForTest(
    Iterable<({DateTime completedAt, int? formScore, int? durationSeconds})>
        samples, {
    DateTime? now,
  }) {
    final end = now ?? DateTime.now();
    final currentStart = end.subtract(const Duration(days: 7));
    final priorStart = end.subtract(const Duration(days: 14));

    var sessions = 0;
    var totalSeconds = 0;
    final currentForms = <int>[];

    var priorSessions = 0;
    var priorSeconds = 0;
    final priorForms = <int>[];

    for (final s in samples) {
      final at = s.completedAt;
      if (!at.isBefore(currentStart) && !at.isAfter(end)) {
        sessions++;
        if (s.durationSeconds != null) totalSeconds += s.durationSeconds!;
        if (s.formScore != null) currentForms.add(s.formScore!);
      } else if (!at.isBefore(priorStart) && at.isBefore(currentStart)) {
        priorSessions++;
        if (s.durationSeconds != null) priorSeconds += s.durationSeconds!;
        if (s.formScore != null) priorForms.add(s.formScore!);
      }
    }

    final avgForm = currentForms.isEmpty ? null : _roundedMean(currentForms);
    // Deltas only read as real once the prior window has >= 3 sessions.
    final hasBaseline = priorSessions >= 3;
    final priorAvgForm = priorForms.isEmpty ? null : _roundedMean(priorForms);

    return (
      sessions: sessions,
      totalSeconds: totalSeconds,
      avgForm: avgForm,
      sessionsDelta: hasBaseline ? sessions - priorSessions : null,
      secondsDelta: hasBaseline ? totalSeconds - priorSeconds : null,
      avgFormDelta: (hasBaseline && avgForm != null && priorAvgForm != null)
          ? avgForm - priorAvgForm
          : null,
    );
  }

  // ─── Progress tab: personal records rail (KỶ LỤC CÁ NHÂN) ───────────

  /// Best (max) form_score per exercise across all of the user's
  /// exercise_sessions, highest-first. Name resolution to a display label is
  /// the caller's job (via the exercise catalog) — this stays DB-only.
  Future<
      List<
          ({
            String exerciseId,
            int bestScore,
            int? previousBest,
            DateTime achievedAt,
          })>> personalRecords() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client
          .from('exercise_sessions')
          .select('exercise_id, form_score, completed_at')
          .eq('user_id', userId)
          .not('form_score', 'is', null)
          .not('completed_at', 'is', null);

      final sessions =
          <({String exerciseId, int formScore, DateTime completedAt})>[];
      for (final raw in rows as List) {
        final row = (raw as Map).cast<String, dynamic>();
        final id = (row['exercise_id'] as String?)?.trim();
        final score = (row['form_score'] as num?)?.toInt();
        final completedAt = _dateTimeOrNull(row['completed_at']);
        if (id == null || id.isEmpty || score == null || completedAt == null) {
          continue;
        }
        sessions
            .add((exerciseId: id, formScore: score, completedAt: completedAt));
      }
      return derivePersonalRecordsForTest(sessions);
    } catch (e) {
      debugPrint('[Vika] personalRecords failed: $e');
      return const [];
    }
  }

  /// Pure best-per-exercise reduction for [personalRecords]. For each
  /// exercise_id: [bestScore] is the max form_score, [achievedAt] is when that
  /// best was FIRST reached, and [previousBest] is the best of the remaining
  /// sessions (null when the exercise has only one logged session). Sorted
  /// highest-score-first, then most-recent-first.
  @visibleForTesting
  static List<
      ({
        String exerciseId,
        int bestScore,
        int? previousBest,
        DateTime achievedAt,
      })> derivePersonalRecordsForTest(
    Iterable<({String exerciseId, int formScore, DateTime completedAt})>
        sessions,
  ) {
    final byExercise =
        <String, List<({int formScore, DateTime completedAt})>>{};
    for (final s in sessions) {
      (byExercise[s.exerciseId] ??= [])
          .add((formScore: s.formScore, completedAt: s.completedAt));
    }

    final records = <({
      String exerciseId,
      int bestScore,
      int? previousBest,
      DateTime achievedAt,
    })>[];
    for (final entry in byExercise.entries) {
      final logs = entry.value;
      var bestScore = logs.first.formScore;
      for (final l in logs) {
        if (l.formScore > bestScore) bestScore = l.formScore;
      }
      // Earliest time the best score was reached.
      DateTime? achievedAt;
      for (final l in logs) {
        if (l.formScore == bestScore &&
            (achievedAt == null || l.completedAt.isBefore(achievedAt))) {
          achievedAt = l.completedAt;
        }
      }
      // Previous best = highest score among the OTHER sessions.
      int? previousBest;
      if (logs.length > 1) {
        for (final l in logs) {
          if (identical(l.completedAt, achievedAt) &&
              l.formScore == bestScore) {
            continue;
          }
          if (previousBest == null || l.formScore > previousBest) {
            previousBest = l.formScore;
          }
        }
      }
      records.add((
        exerciseId: entry.key,
        bestScore: bestScore,
        previousBest: previousBest,
        achievedAt: achievedAt!,
      ));
    }

    records.sort((a, b) {
      final byScore = b.bestScore.compareTo(a.bestScore);
      if (byScore != 0) return byScore;
      return b.achievedAt.compareTo(a.achievedAt);
    });
    return records;
  }

  // ─── Progress tab: ranked insights (BÀI TẬP NỔI BẬT) ────────────────

  /// Minimum Theil-Sen slope (per session) a candidate must clear to count as
  /// a real improvement. Slopes live on a 0..100-per-session scale — form is
  /// points/session, a fault rate is percentage-points/session — so one
  /// threshold gates every tier comparably. Flat or below this reads as noise,
  /// not progress. Tunable.
  static const double MIN_FORM_SLOPE = 1.5;
  static const double MIN_FAULT_RATE_SLOPE = 0.03;

  /// Per-exercise improvement ranking for the BÀI TẬP NỔI BẬT cards, scoped to
  /// a [PeriodTab] window. Pulls each exercise's sessions oldest-first, derives
  /// one headline per qualifying exercise, and returns them already sorted
  /// (best first). Name resolution + copy formatting is the caller's job. DB
  /// errors and signed-out fall back to an empty list (the section shows its
  /// guided empty).
  Future<List<RankInsightHeadline>> rankedInsights(PeriodTab period) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final now = DateTime.now();
      final since = switch (period) {
        PeriodTab.week => now.subtract(const Duration(days: 7)),
        PeriodTab.month => now.subtract(const Duration(days: 30)),
        // TODO(wiring): single-program MVP — all completed sessions. Scope to
        // the active program (recommendation_id) once history lands.
        PeriodTab.program => null,
      };

      var query = _client
          .from('exercise_sessions')
          .select(
              'exercise_id, form_score, fault_counts, total_reps, completed_at')
          .eq('user_id', userId)
          .not('form_score', 'is', null)
          .not('total_reps', 'is', null)
          .not('completed_at', 'is', null);
      if (since != null) {
        query = query.gte('completed_at', since.toUtc().toIso8601String());
      }
      // Oldest-first so the session order index is the x-axis for every slope.
      final rows = await query.order('completed_at', ascending: true);

      final sessions = <RankInsightSession>[];
      for (final raw in rows as List) {
        final row = (raw as Map).cast<String, dynamic>();
        final id = (row['exercise_id'] as String?)?.trim();
        final score = (row['form_score'] as num?)?.toInt();
        final reps = (row['total_reps'] as num?)?.toInt();
        if (id == null || id.isEmpty || score == null || reps == null) continue;
        final faultRaw = (row['fault_counts'] as Map?) ?? const {};
        sessions.add((
          exerciseId: id,
          formScore: score,
          totalReps: reps,
          faultCounts: {
            for (final e in faultRaw.entries)
              (e.key as String): (e.value as num).toInt(),
          },
        ));
      }

      // Per-exercise metadata from the report-builder registry. Unregistered
      // exercises fall back to GenericReportBuilder (empty maps) → form-only.
      final metaByExercise = <String, RankInsightMeta>{};
      for (final id in sessions.map((s) => s.exerciseId).toSet()) {
        final builder = resolveReportBuilder(id).builder;
        metaByExercise[id] = (
          painToFaultMap: builder.painToFaultMap(),
          praiseMetricNames: builder.praiseMetricNames(),
        );
      }

      final painAreas = (await getActivePainAreas()).toSet();
      return deriveRankedInsightsForTest(
        sessions: sessions,
        activePainAreas: painAreas,
        metaByExercise: metaByExercise,
      );
    } catch (e) {
      debugPrint('[Vika] rankedInsights failed: $e');
      return const [];
    }
  }

  /// Pure per-exercise improvement ranking for [rankedInsights]. DB-free so the
  /// tier ladder + Theil-Sen math stay unit-testable. [sessions] are flat and
  /// oldest-first; they're grouped by exercise preserving that order. An
  /// exercise with fewer than 3 sessions in the window does not qualify and is
  /// skipped entirely. Returns headlines sorted by tier rank asc, then slope
  /// magnitude desc, with a stable exercise-id hash as the deterministic
  /// tiebreak (never random per render). Empty when nothing qualifies.
  @visibleForTesting
  static List<RankInsightHeadline> deriveRankedInsightsForTest({
    required Iterable<RankInsightSession> sessions,
    required Set<String> activePainAreas,
    required Map<String, RankInsightMeta> metaByExercise,
    double minFormSlope = MIN_FORM_SLOPE,
    double minFaultRateSlope = MIN_FAULT_RATE_SLOPE,
  }) {
    final byExercise = <String, List<RankInsightSession>>{};
    for (final s in sessions) {
      (byExercise[s.exerciseId] ??= []).add(s);
    }

    const emptyMeta = (
      painToFaultMap: <String, List<String>>{},
      praiseMetricNames: <String, String>{},
    );

    final headlines = <RankInsightHeadline>[];
    for (final entry in byExercise.entries) {
      final series = entry.value;
      if (series.length < 3) continue; // too few sessions to read a slope
      final headline = _exerciseHeadline(
        exerciseId: entry.key,
        series: series,
        activePainAreas: activePainAreas,
        meta: metaByExercise[entry.key] ?? emptyMeta,
        minFormSlope: minFormSlope,
        minFaultRateSlope: minFaultRateSlope,
      );
      if (headline != null) headlines.add(headline);
    }

    headlines.sort((a, b) {
      final byTier = a.tier.index.compareTo(b.tier.index);
      if (byTier != 0) return byTier;
      final bySlope = b.slopeMagnitude.compareTo(a.slopeMagnitude);
      if (bySlope != 0) return bySlope;
      return _stableHash(a.exerciseId).compareTo(_stableHash(b.exerciseId));
    });
    return headlines;
  }

  /// Picks the single headline for one exercise's [series], walking the tier
  /// ladder pain-fault → form → generic-fault and returning the first tier that
  /// has a qualifying candidate. Null when no tier clears its threshold.
  static RankInsightHeadline? _exerciseHeadline({
    required String exerciseId,
    required List<RankInsightSession> series,
    required Set<String> activePainAreas,
    required RankInsightMeta meta,
    required double minFormSlope,
    required double minFaultRateSlope,
  }) {
    // Fault keys linked to one of the user's ACTIVE pain areas for this
    // exercise (union over the active areas).
    final painFaultKeys = <String>{};
    for (final area in activePainAreas) {
      final keys = meta.painToFaultMap[area];
      if (keys != null) painFaultKeys.addAll(keys);
    }

    // Tier 0 — pain-linked faults.
    final pain = _bestFaultCandidate(
      series: series,
      faultKeys: painFaultKeys,
      labels: meta.praiseMetricNames,
      minFaultRateSlope: minFaultRateSlope,
    );
    if (pain != null) {
      return (
        exerciseId: exerciseId,
        tier: InsightTier.pain,
        faultKey: pain.faultKey,
        metricLabel: pain.label,
        slopeMagnitude: pain.slope,
        fromValue: pain.fromValue,
        toValue: pain.toValue,
        series: pain.series,
        lowerIsBetter: true,
      );
    }

    // Tier 1 — form (raw form score, slope as-is).
    final fit = _theilSen([for (final s in series) s.formScore.toDouble()]);
    if (fit.slope >= minFormSlope) {
      return (
        exerciseId: exerciseId,
        tier: InsightTier.form,
        faultKey: null,
        metricLabel: null,
        slopeMagnitude: fit.slope,
        fromValue: _fitted(fit, 0, series.length),
        toValue: _fitted(fit, series.length - 1, series.length),
        // Actual per-session form scores, oldest-first, for the bar chart.
        series: [for (final s in series) s.formScore.clamp(0, 100)],
        lowerIsBetter: false,
      );
    }

    // Tier 2 — generic faults (every other fault key seen in the window).
    final allFaultKeys = <String>{};
    for (final s in series) {
      allFaultKeys.addAll(s.faultCounts.keys);
    }
    final generic = _bestFaultCandidate(
      series: series,
      faultKeys: allFaultKeys.difference(painFaultKeys),
      labels: meta.praiseMetricNames,
      minFaultRateSlope: minFaultRateSlope,
    );
    if (generic != null) {
      return (
        exerciseId: exerciseId,
        tier: InsightTier.generic,
        faultKey: generic.faultKey,
        metricLabel: generic.label,
        slopeMagnitude: generic.slope,
        fromValue: generic.fromValue,
        toValue: generic.toValue,
        series: generic.series,
        lowerIsBetter: true,
      );
    }

    return null;
  }

  /// Best (largest oriented slope) qualifying fault candidate among [faultKeys].
  /// A candidate's y-series is the per-session fault RATE as a % of reps
  /// (rep-volume adjusted, 0..100); the slope is sign-flipped so a FALLING rate
  /// reads positive. A key with no [labels] entry can't be rendered and is
  /// skipped — this is why GenericReportBuilder exercises never reach a fault
  /// tier. Null when none clears [minFaultRateSlope].
  static ({
    String faultKey,
    String label,
    double slope,
    int fromValue,
    int toValue,
    List<int> series,
  })? _bestFaultCandidate({
    required List<RankInsightSession> series,
    required Set<String> faultKeys,
    required Map<String, String> labels,
    required double minFaultRateSlope,
  }) {
    ({
      String faultKey,
      String label,
      double slope,
      int fromValue,
      int toValue,
      List<int> series,
    })? best;
    for (final key in faultKeys) {
      final label = labels[key];
      if (label == null || label.isEmpty) continue; // unlabelled → unrenderable

      final rates = <double>[
        for (final s in series)
          s.totalReps > 0 ? (s.faultCounts[key] ?? 0) / s.totalReps * 100 : 0.0,
      ];
      final fit = _theilSen(rates);
      final improvement = -fit.slope; // falling rate = positive improvement
      if (improvement < minFaultRateSlope) continue;

      if (best == null || improvement > best.slope) {
        // Fitted endpoints stay in real rate% (not oriented), so from > to.
        best = (
          faultKey: key,
          label: label,
          slope: improvement,
          fromValue: _fitted(fit, 0, series.length),
          toValue: _fitted(fit, series.length - 1, series.length),
          // Actual per-session rate %, oldest-first, for the bar chart.
          series: [for (final r in rates) r.round().clamp(0, 100)],
        );
      }
    }
    return best;
  }

  /// Theil-Sen fitted value at session index [x], rounded and clamped to the
  /// 0..100 display range. [n] is the series length (unused beyond clarity).
  static int _fitted(({double slope, double intercept}) fit, int x, int n) =>
      (fit.slope * x + fit.intercept).round().clamp(0, 100);

  /// Theil-Sen line fit over points (i, y[i]): slope = median of all pairwise
  /// slopes (y_j − y_i)/(j − i) for i < j; intercept = median of (y_i − slope·i).
  /// All-pairs is fine at the session counts here (n ≲ 12).
  static ({double slope, double intercept}) _theilSen(List<double> y) {
    final n = y.length;
    final pairwise = <double>[];
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        pairwise.add((y[j] - y[i]) / (j - i));
      }
    }
    final slope = _median(pairwise);
    final intercept = _median([for (var i = 0; i < n; i++) y[i] - slope * i]);
    return (slope: slope, intercept: intercept);
  }

  /// Median of [values] (0 when empty). Does not mutate the input.
  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Deterministic 32-bit FNV-1a hash — a stable per-render tiebreak for the
  /// ranking sort (String.hashCode can vary across runs).
  static int _stableHash(String s) {
    var hash = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  // ─── Streak milestones (consecutive active weeks) ───────────────────

  /// Smallest streak-tier milestone strictly greater than [weeks] (in
  /// consecutive active weeks). Always defined — past the final fixed tier it
  /// returns the next whole year. Delegates to the shared streak ladder.
  static int nextStreakMilestone(int weeks) => nextStreakMilestoneWeek(weeks);

  // ─── Progress tab: trajectory fact (score gauge) ────────────────────

  /// "high" threshold separating the steady-high row from the plain-steady
  /// row in [deriveTrajectoryFactForTest]. Tunable.
  static const int kTrajectoryHighThreshold = 80;

  /// A factual one-liner about the score TREND for the gauge card — NOT
  /// coaching, NOT the session coach. [trend] is the window's session form
  /// scores oldest-first; [netChange] is the Theil-Sen fitted change across the
  /// span (fitted last − fitted first), and [average] is the window mean (the
  /// gauge headline) — both null below the 3-session baseline, per the gauge
  /// gate. Priority-ordered, first match wins; rows 4–9 never fire below N >= 3.
  @visibleForTesting
  static String deriveTrajectoryFactForTest({
    required List<int> trend,
    required int? netChange,
    required int? average,
    int highThreshold = kTrajectoryHighThreshold,
  }) {
    final n = trend.length;
    if (n == 0) return '';
    final to = trend.last;
    final maxV = trend.reduce(math.max);

    // 1 — new all-time high (needs a prior point for "high" to mean anything).
    if (n >= 2 && to == maxV) return 'Điểm form cao nhất từ trước đến giờ.';
    // 2 / 3 — pre-baseline framing.
    if (n == 1) return 'Buổi đầu đã xong, Vika bắt đầu theo dõi form.';
    if (n == 2) return 'Hai buổi rồi, thêm một buổi nữa là thấy xu hướng.';
    // 4–9 — only with a real baseline (N >= 3, netChange + average resolved).
    // Driven by the Theil-Sen span change, not latest-minus-first; the steady
    // rows read the AVERAGE (the headline) against the high threshold.
    if (n >= 3 && netChange != null && average != null) {
      if (netChange >= 8) return 'Form lên rõ qua $n buổi.';
      if (netChange >= 3) return 'Form đang đi lên.';
      if (netChange >= -2) {
        return average >= highThreshold
            ? 'Giữ vững phong độ cao.'
            : 'Form ổn định.';
      }
      if (netChange >= -7) {
        return 'Form chững lại một chút so với đầu giai đoạn.';
      }
      return 'Form thấp hơn đầu giai đoạn.';
    }
    // Defensive: N >= 3 but trend unresolved (shouldn't happen given the gate).
    return 'Form ổn định.';
  }

  // ─── Progress tab: milestone rail (CỘT MỐC) ─────────────────────────

  /// Unlock state for the full [milestoneCatalog], computed from the user's
  /// completed workout_sessions plus their weekly scheduled-session count.
  /// One round trip for sessions, one for the schedule; the unlock math lives
  /// in [deriveUnlockedMilestonesForTest] so it stays unit-testable.
  Future<List<Milestone>> milestones() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return deriveUnlockedMilestonesForTest(const [], scheduledPerWeek: 0);
    }

    try {
      final rows = await _client
          .from('workout_sessions')
          .select('completed_at, raw_form_score')
          .eq('user_id', userId)
          .not('completed_at', 'is', null)
          .order('completed_at', ascending: true);

      final samples = <({DateTime completedAt, int? rawFormScore})>[];
      for (final raw in rows as List) {
        final row = (raw as Map).cast<String, dynamic>();
        final completedAt = _dateTimeOrNull(row['completed_at']);
        if (completedAt == null) continue;
        samples.add((
          completedAt: completedAt,
          rawFormScore: (row['raw_form_score'] as num?)?.toInt(),
        ));
      }

      return deriveUnlockedMilestonesForTest(
        samples,
        scheduledPerWeek: await _scheduledSessionsPerWeek(userId),
      );
    } catch (e) {
      debugPrint('[Vika] milestones failed: $e');
      return deriveUnlockedMilestonesForTest(const [], scheduledPerWeek: 0);
    }
  }

  /// Weekly scheduled-session count from `profiles.schedule_sessions` (the
  /// same source the recommendation engine reads). 0 when unset — which leaves
  /// the consistency rungs locked rather than trivially unlocked.
  Future<int> _scheduledSessionsPerWeek(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('schedule_sessions')
          .eq('id', userId)
          .maybeSingle();
      final list = (row?['schedule_sessions'] as List?) ?? const [];
      return list.length;
    } catch (e) {
      debugPrint('[Vika] _scheduledSessionsPerWeek failed: $e');
      return 0;
    }
  }

  /// Pure unlock computation for [milestones]. [sessions] are completed
  /// sessions in any order; [scheduledPerWeek] is the user's weekly scheduled
  /// count (0 disables the consistency rungs). `now` is accepted for symmetry
  /// with the other derivers (unused here — every rung is all-time).
  ///
  ///   Streak     — all-time LONGEST run of consecutive ACTIVE WEEKS (a week
  ///                with >= 1 session), measured in weeks.
  ///   Sessions   — count of completed sessions.
  ///   Form       — any session's raw_form_score.
  ///   Tuần       — a Mon–Sun week with >= [scheduledPerWeek] sessions.
  ///   Tháng      — a calendar month with >= [scheduledPerWeek] * 4 sessions.
  ///
  /// Each unlocked rung carries the 'd/M' date its threshold was first crossed.
  @visibleForTesting
  static List<Milestone> deriveUnlockedMilestonesForTest(
    Iterable<({DateTime completedAt, int? rawFormScore})> sessions, {
    required int scheduledPerWeek,
    DateTime? now,
    List<Milestone> catalog = milestoneCatalog,
  }) {
    final sorted = [...sessions]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final local = [
      for (final s in sorted)
        (
          date: _LocalDate.fromDateTime(s.completedAt.toLocal()),
          at: s.completedAt.toLocal(),
          form: s.rawFormScore,
        ),
    ];

    String fmt(DateTime d) => '${d.day}/${d.month}';

    // Sessions: date of the nth completion.
    DateTime? nthSessionDate(int n) =>
        local.length >= n ? local[n - 1].at : null;

    // Form: earliest session reaching >= threshold.
    DateTime? formReachDate(int threshold) {
      for (final s in local) {
        if (s.form != null && s.form! >= threshold) return s.at;
      }
      return null;
    }

    // Streak: bucket completions by their local ISO-week Monday, walk the
    // unique weeks ascending tracking the current run; the week a run first
    // reaches [threshold] (in weeks) is when it was crossed. `local` is already
    // sorted ascending, so the week Mondays come out ascending too.
    final uniqueWeeks = <_LocalDate>[];
    final seenWeeks = <_LocalDate>{};
    for (final s in local) {
      final monday = _mondayOf(s.date);
      if (seenWeeks.add(monday)) uniqueWeeks.add(monday);
    }
    DateTime? streakReachDate(int threshold) {
      var run = 0;
      _LocalDate? prev;
      for (final w in uniqueWeeks) {
        final adjacent = prev != null &&
            DateTime(w.year, w.month, w.day)
                    .difference(DateTime(prev.year, prev.month, prev.day))
                    .inDays ==
                7;
        run = adjacent ? run + 1 : 1;
        if (run >= threshold) return DateTime(w.year, w.month, w.day);
        prev = w;
      }
      return null;
    }

    // Consistency: re-walk in order, accumulating per-span counts; the session
    // that pushes a span to its target is when the rung was crossed.
    DateTime? weekReachDate() {
      if (scheduledPerWeek <= 0) return null;
      final running = <_LocalDate, int>{};
      for (final s in local) {
        final monday = _mondayOf(s.date);
        final c = (running[monday] ?? 0) + 1;
        running[monday] = c;
        if (c >= scheduledPerWeek) return s.at;
      }
      return null;
    }

    DateTime? monthReachDate() {
      if (scheduledPerWeek <= 0) return null;
      final target = scheduledPerWeek * 4;
      final running = <int, int>{};
      for (final s in local) {
        final key = s.date.year * 100 + s.date.month;
        final c = (running[key] ?? 0) + 1;
        running[key] = c;
        if (c >= target) return s.at;
      }
      return null;
    }

    return [
      for (final m in catalog)
        () {
          final DateTime? on = switch (m.category) {
            MilestoneCategory.streak => streakReachDate(m.threshold),
            MilestoneCategory.sessions => nthSessionDate(m.threshold),
            MilestoneCategory.form => formReachDate(m.threshold),
            MilestoneCategory.consistency => m.threshold == kConsistencyWeek
                ? weekReachDate()
                : monthReachDate(),
          };
          return on == null ? m : m.asUnlocked(fmt(on));
        }(),
    ];
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
    final canonicalRegion = canonicalPainRegion(region);
    if (canonicalRegion == null) return;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final clampedIntensity = intensity.clamp(1, 5).toInt();
      final now = DateTime.now().toIso8601String();
      final existing = await _client
          .from('user_pain_areas')
          .select('id, flag_count')
          .eq('user_id', userId)
          .eq('body_region', canonicalRegion)
          .eq('status', 'active')
          .maybeSingle();

      if (existing != null) {
        // Reaffirm: read-modify-write flag_count. Not atomic, but a single
        // user tapping one region isn't a contention case. Source is left as
        // is on purpose — do not downgrade a 'confirmed' row.
        final newCount = ((existing['flag_count'] as num?)?.toInt() ?? 1) + 1;
        await _client.from('user_pain_areas').update({
          'intensity': clampedIntensity,
          'last_reaffirmed_at': now,
          'flag_count': newCount,
          if (canonicalRegion == kOtherPainRegion && notes != null)
            'notes': notes,
        }).eq('id', existing['id']);
      } else {
        await _client.from('user_pain_areas').insert({
          'user_id': userId,
          'body_region': canonicalRegion,
          'source': 'self_reported',
          'status': 'active',
          'intensity': clampedIntensity,
          'first_flagged_at': now,
          'last_reaffirmed_at': now,
          'flag_count': 1,
          if (canonicalRegion == kOtherPainRegion && notes != null)
            'notes': notes,
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

/// The Monday (local) of the Mon–Sun week containing [d].
_LocalDate _mondayOf(_LocalDate d) {
  final dt = DateTime(d.year, d.month, d.day);
  final monday = dt.subtract(Duration(days: dt.weekday - 1));
  return _LocalDate(monday.year, monday.month, monday.day);
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

  _LocalDate get next {
    final value = DateTime(year, month, day + 1);
    return _LocalDate(value.year, value.month, value.day);
  }

  /// Same weekday one week earlier — used to walk week buckets (callers pass
  /// the Monday of a week, so this steps to the previous week's Monday).
  _LocalDate get previousWeek {
    final value = DateTime(year, month, day - 7);
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
