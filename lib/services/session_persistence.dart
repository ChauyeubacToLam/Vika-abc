import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// User-level stats loaded from the profiles table.
/// Single source of truth for streak and last workout timestamp.
class UserStats {
  final int streakDays;
  final DateTime? lastWorkoutDate;

  const UserStats({
    required this.streakDays,
    this.lastWorkoutDate,
  });

  factory UserStats.fromRow(Map<String, dynamic> row) {
    return UserStats(
      streakDays: (row['streak'] as num?)?.toInt() ?? 0,
      lastWorkoutDate: row['last_workout_at'] != null
          ? DateTime.parse(row['last_workout_at'] as String)
          : null,
    );
  }
}

/// Persistence layer for exercise sessions + user-level stats.
/// All methods are fire-and-forget where possible — errors are logged
/// but do not interrupt the workout UX.
class SessionPersistence {
  final _client = Supabase.instance.client;

  // ─── Exercise sessions ─────────────────────────────────────────────

  /// Save a completed exercise session. Fire-and-forget.
  /// Returns session ID on success, null on failure.
  ///
  /// [difficultyRatings] should be one entry per set, null for skipped sets
  /// (e.g. `[heavy, null, medium]` when the user skipped rating set 2).
  /// [overallDifficulty] is captured later via updateSessionDifficulty().
  Future<String?> saveSession({
    required String exerciseId,
    required DateTime startedAt,
    required int formScore,
    required int totalReps,
    required int totalGoodReps,
    required int totalSets,
    required int? calories,
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
          })
          .select('id')
          .single();

      return response['id'] as String;
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

  // ─── User-level stats (profiles table) ─────────────────────────────

  /// Read user-level stats (streak, last workout date) from profiles.
  /// Returns null if user is not authenticated or query fails.
  Future<UserStats?> getUserStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final row = await _client
          .from('profiles')
          .select('streak, last_workout_at')
          .eq('id', userId) // profiles PK is 'id', matches auth.users.id
          .maybeSingle();

      if (row == null) return null;
      return UserStats.fromRow(row);
    } catch (e) {
      debugPrint('[Vika] getUserStats failed: $e');
      return null;
    }
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

  /// Update streak + last_workout_at on profiles after a session completes.
  /// Rules:
  /// - Same calendar day as last workout: no change (user did multiple sessions today)
  /// - Gap of 1 day: increment streak
  /// - Gap of 2+ days: reset to 1
  /// - No previous workout: set to 1
  /// Fire-and-forget. Errors logged but do not interrupt UX.
  Future<void> updateStreak() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final stats = await getUserStats();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int newStreak;
      if (stats?.lastWorkoutDate == null) {
        newStreak = 1;
      } else {
        final lastDate = DateTime(
          stats!.lastWorkoutDate!.year,
          stats.lastWorkoutDate!.month,
          stats.lastWorkoutDate!.day,
        );
        final dayDiff = today.difference(lastDate).inDays;

        if (dayDiff == 0) {
          newStreak = stats.streakDays; // same day, no change
        } else if (dayDiff == 1) {
          newStreak = stats.streakDays + 1; // consecutive day
        } else {
          newStreak = 1; // gap, reset
        }
      }

      await _client.from('profiles').update({
        'streak': newStreak,
        'last_workout_at': now.toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('[Vika] updateStreak failed: $e');
    }
  }
}
