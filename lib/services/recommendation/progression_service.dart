import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/exercise_catalog_entry.dart';
import 'progression_rules.dart';

class RecommendationProgressionService {
  RecommendationProgressionService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, String>> fetchUnlockedVariants(String userId) async {
    try {
      final rows = await _client
          .from('user_exercise_capacity')
          .select('exercise_id, unlocked_next_id')
          .eq('user_id', userId)
          .not('unlocked_next_id', 'is', null);

      return {
        for (final row in rows as List)
          (row as Map<String, dynamic>)['exercise_id'] as String:
              row['unlocked_next_id'] as String,
      };
    } catch (e) {
      debugPrint('[RecommendationProgression] unlock fetch failed: $e');
      return const {};
    }
  }

  Future<Map<String, CarryOverPerformance>> fetchCarryOvers(
    String userId, {
    int limit = 80,
  }) async {
    try {
      final capacityRows = await _client
          .from('user_exercise_capacity')
          .select(
            'exercise_id, last_final_reps, last_final_rest_seconds, last_avg_difficulty, last_was_deload, last_session_at',
          )
          .eq('user_id', userId)
          .not('last_session_at', 'is', null)
          .order('last_session_at', ascending: false)
          .limit(limit);

      final fromCapacity = <String, CarryOverPerformance>{};
      for (final raw in capacityRows as List) {
        final row = (raw as Map).cast<String, dynamic>();
        final exerciseId = row['exercise_id'] as String?;
        if (exerciseId == null || row['last_was_deload'] == true) continue;
        fromCapacity[exerciseId] = CarryOverPerformance(
          reps: _intValue(row['last_final_reps']),
          appliedRestSeconds: _intValue(row['last_final_rest_seconds']),
          wasHard: row['last_avg_difficulty'] == 'hard',
          isDeloadSource: row['last_was_deload'] == true,
        );
      }
      final rows = await _client
          .from('exercise_sessions')
          .select('exercise_id, difficulty_ratings, set_data, completed_at')
          .eq('user_id', userId)
          .order('completed_at', ascending: false)
          .limit(limit);

      final fromSessions = <String, CarryOverPerformance>{};
      for (final raw in rows as List) {
        final row = raw as Map<String, dynamic>;
        final exerciseId = row['exercise_id'] as String?;
        if (exerciseId == null || fromSessions.containsKey(exerciseId)) {
          continue;
        }

        final carryOver = parseCarryOverFromSessionRow(row);
        if (carryOver == null || carryOver.isDeloadSource) continue;
        fromSessions[exerciseId] = carryOver;
      }

      // Session payloads carry both reps and seconds; the capacity cache only
      // has last_final_reps today. Prefer the richer session source so hybrid
      // seconds reach applyCarryOverFloor, while retaining capacity as fallback
      // for exercises outside the recent-session query window.
      return {...fromCapacity, ...fromSessions};
    } catch (e) {
      debugPrint('[RecommendationProgression] carry-over fetch failed: $e');
      return const {};
    }
  }

  Future<void> recordCompletedSession({
    required String userId,
    required String sessionId,
    required String exerciseId,
    required List<String?> difficultyRatings,
    required List<Map<String, dynamic>> setData,
  }) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('fitness_level')
          .eq('id', userId)
          .maybeSingle();
      final fitnessLevel = (profile?['fitness_level'] as String?) ?? 'beginner';
      final tier = levelToTier(fitnessLevel);

      final row = await _client
          .from('exercise_catalog')
          .select()
          .eq('id', exerciseId)
          .maybeSingle();
      if (row == null) return;

      final exercise = ExerciseCatalogEntry.fromSupabase(row);
      final existing = await _client
          .from('user_exercise_capacity')
          .select('target_hit_streak, unlocked_next_id')
          .eq('user_id', userId)
          .eq('exercise_id', exerciseId)
          .maybeSingle();

      final currentStreak =
          (existing?['target_hit_streak'] as num?)?.toInt() ?? 0;
      final alreadyUnlocked = existing?['unlocked_next_id'] as String?;
      final qualifies = sessionQualifiesForVariantUnlock(
        exercise: exercise,
        userTier: tier,
        difficultyRatings: difficultyRatings,
        setData: setData,
      );

      final nextStreak = qualifies ? currentStreak + 1 : 0;
      final nextUnlock = alreadyUnlocked ??
          (nextStreak >= kDefaultVariantUnlockStreak
              ? exercise.progressionTo
              : null);
      final carryOver = parseCarryOverFromSessionPayload(
        difficultyRatings: difficultyRatings,
        setData: setData,
      );

      await _client.from('user_exercise_capacity').upsert(
        {
          'user_id': userId,
          'exercise_id': exerciseId,
          'target_hit_streak': nextStreak,
          'unlocked_next_id': nextUnlock,
          'last_final_reps': carryOver?.reps,
          'last_final_rest_seconds': carryOver?.appliedRestSeconds,
          'last_avg_difficulty': _sessionDifficultyLabel(difficultyRatings),
          'last_was_deload': carryOver?.isDeloadSource ?? false,
          'last_session_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,exercise_id',
      );
    } catch (e) {
      debugPrint('[RecommendationProgression] session update failed: $e');
    }
  }

  Future<List<VariantUnlockNotice>> fetchPendingUnlockNotices(
    String userId, {
    String? recommendationId,
  }) async {
    try {
      final rows = await _client
          .from('user_exercise_capacity')
          .select('exercise_id, unlocked_next_id')
          .eq('user_id', userId)
          .not('unlocked_next_id', 'is', null);

      final rawRows = (rows as List).cast<Map<String, dynamic>>();
      if (rawRows.isEmpty) return const [];
      final shownKeys = await _readShownUnlockKeys();

      final ids = rawRows
          .expand((row) => [
                row['exercise_id'] as String,
                row['unlocked_next_id'] as String,
              ])
          .toSet()
          .toList();
      final catalogRows = await _client
          .from('exercise_catalog')
          .select('id, vietnamese_name, english_name')
          .inFilter('id', ids);
      final namesById = {
        for (final raw in catalogRows as List)
          (raw as Map<String, dynamic>)['id'] as String:
              ((raw['vietnamese_name'] as String?) ??
                  (raw['english_name'] as String?) ??
                  raw['id'] as String),
      };

      return rawRows
          .map((row) {
            final fromId = row['exercise_id'] as String;
            final toId = row['unlocked_next_id'] as String;
            return VariantUnlockNotice(
              exerciseId: fromId,
              exerciseName: namesById[fromId] ?? fromId,
              unlockedExerciseId: toId,
              unlockedExerciseName: namesById[toId] ?? toId,
            );
          })
          .where((notice) =>
              recommendationId == null ||
              !shownKeys.contains(notice.storageKey(recommendationId)))
          .toList();
    } catch (e) {
      debugPrint('[RecommendationProgression] unlock notice fetch failed: $e');
      return const [];
    }
  }

  Future<void> markUnlockNoticesApplied({
    required String userId,
    required String recommendationId,
    required List<VariantUnlockNotice> notices,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_shownUnlockPrefsKey) ?? const [];
    final next = {
      ...current,
      for (final notice in notices) notice.storageKey(recommendationId),
    }.toList();
    await prefs.setStringList(_shownUnlockPrefsKey, next);
  }

  Future<Set<String>> _readShownUnlockKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_shownUnlockPrefsKey) ?? const []).toSet();
    } catch (_) {
      return const {};
    }
  }
}

class VariantUnlockNotice {
  const VariantUnlockNotice({
    required this.exerciseId,
    required this.exerciseName,
    required this.unlockedExerciseId,
    required this.unlockedExerciseName,
  });

  final String exerciseId;
  final String exerciseName;
  final String unlockedExerciseId;
  final String unlockedExerciseName;

  String storageKey(String recommendationId) {
    return '$recommendationId:$exerciseId:$unlockedExerciseId';
  }
}

const _shownUnlockPrefsKey = 'shown_variant_unlock_notices';

CarryOverPerformance? parseCarryOverFromSessionRow(Map<String, dynamic> row) {
  final ratings = _stringList(row['difficulty_ratings']);
  final setData = _mapList(row['set_data']);
  return parseCarryOverFromSessionPayload(
    difficultyRatings: ratings,
    setData: setData,
  );
}

CarryOverPerformance? parseCarryOverFromSessionPayload({
  required List<String?> difficultyRatings,
  required List<Map<String, dynamic>> setData,
}) {
  if (setData.isEmpty) return null;

  final finalSet = setData.last;
  final isDeload = finalSet['is_deload_week'] == true;
  final wasHard = difficultyRatings.any(_isHardRating);

  final actualReps =
      _intValue(finalSet['actual_reps']) ?? _intValue(finalSet['total_reps']);
  final actualSeconds = _intValue(finalSet['actual_seconds']) ??
      _intValue(finalSet['total_seconds']);
  final appliedRest = _intValue(finalSet['applied_rest']) ??
      _intValue(finalSet['applied_rest_seconds']);

  return CarryOverPerformance(
    reps: actualReps,
    seconds: actualSeconds,
    appliedRestSeconds: appliedRest,
    wasHard: wasHard,
    isDeloadSource: isDeload,
  );
}

bool sessionQualifiesForVariantUnlock({
  required ExerciseCatalogEntry exercise,
  required int userTier,
  required List<String?> difficultyRatings,
  required List<Map<String, dynamic>> setData,
}) {
  if (exercise.progressionTo == null || setData.isEmpty) return false;

  final carryOver = parseCarryOverFromSessionPayload(
    difficultyRatings: difficultyRatings,
    setData: setData,
  );
  if (carryOver == null || carryOver.isDeloadSource) return false;

  final answered = difficultyRatings.whereType<String>().toList();
  if (answered.isEmpty || !answered.every(_isEasyRating)) return false;

  if (exercise.isRepBased) {
    final reps = carryOver.reps;
    if (reps == null) return false;
    return reps >= tierRepCap(exercise: exercise, tier: userTier);
  }

  if (exercise.isHybridHold) {
    final seconds = carryOver.seconds;
    if (seconds == null) return false;
    return seconds >= tierSecondCap(exercise: exercise, tier: userTier);
  }

  return false;
}

String normalizeSetDifficultyForRecommendation(String raw) {
  return switch (raw) {
    'light' => 'easy',
    'easy' => 'easy',
    'heavy' => 'hard',
    'hard' => 'hard',
    _ => 'ok',
  };
}

bool _isEasyRating(String? value) {
  return value == 'easy' || value == 'light';
}

bool _isHardRating(String? value) {
  return value == 'hard' || value == 'heavy';
}

String? _sessionDifficultyLabel(List<String?> ratings) {
  final answered = ratings.whereType<String>().toList();
  if (answered.isEmpty) return null;
  if (answered.every(_isEasyRating)) return 'easy';
  if (answered.any(_isHardRating)) return 'hard';
  return 'mixed';
}

int? _intValue(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String?> _stringList(dynamic value) {
  if (value == null) return const [];
  return (value as List).map((item) => item as String?).toList();
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value == null) return const [];
  return (value as List)
      .map((item) => (item as Map).cast<String, dynamic>())
      .toList();
}
