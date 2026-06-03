import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vika/services/session_persistence.dart';

import 'models/exercise_catalog_entry.dart';
import 'models/plan.dart';
import 'models/recommendation_result.dart';
import 'progression_service.dart';
import 'recommendation_engine.dart';
import 'templates.dart';

class RecommendationService {
  RecommendationService({
    SupabaseClient? client,
    RecommendationEngine? engine,
    RecommendationProgressionService? progressionService,
    SessionPersistence? sessions,
  })  : _client = client ?? Supabase.instance.client,
        _engine = engine ?? const RecommendationEngine(),
        _progression = progressionService ??
            RecommendationProgressionService(client: client),
        _sessions = sessions ?? SessionPersistence();

  final SupabaseClient _client;
  final RecommendationEngine _engine;
  final RecommendationProgressionService _progression;
  final SessionPersistence _sessions;
  static const _latestRecommendationIdKey = 'latest_recommendation_id';

  Future<RecommendationResult?> generatePlanForCurrentUser({
    String trigger = 'onboarding',
    String planScope = kPlanScopeFull,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await _client
          .from('profiles')
          .select(
            'fitness_level, fork, goals, training_duration, schedule_sessions',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null) return null;

      final catalogRows = await _client
          .from('exercise_catalog')
          .select()
          .eq('is_form_checked', true);
      final catalog = (catalogRows as List)
          .map((row) => ExerciseCatalogEntry.fromSupabase(
                (row as Map).cast<String, dynamic>(),
              ))
          .toList(growable: false);

      final activePainAreas = await _fetchActivePainAreas(user.id);
      final recentExerciseIds = await _fetchRecentExerciseIds(user.id);
      final unlocked = await _progression.fetchUnlockedVariants(user.id);
      final carryOvers = await _progression.fetchCarryOvers(user.id);

      final goals = (profile['goals'] as List?)?.cast<String>() ?? const [];
      final goal = goals.isEmpty ? 'health' : goals.first;
      final fork = profile['fork'] as String?;
      final template = templateFor(fork: fork, goal: goal);
      final schedule = (profile['schedule_sessions'] as List?) ?? const [];
      final sessionsPerWeek =
          schedule.isEmpty ? 3 : schedule.length.clamp(1, 7);
      final recommendationId = _uuidV4();
      final rngSeed = '$recommendationId:${user.id}:${DateTime.now().day}';

      final result = _engine.generatePlan(
        RecommendationRequest(
          recommendationId: recommendationId,
          userId: user.id,
          template: template,
          catalog: catalog,
          fitnessLevel: (profile['fitness_level'] as String?) ?? 'beginner',
          goalKey: goal,
          activePainAreas: activePainAreas,
          recentExerciseIds: recentExerciseIds,
          rngSeed: rngSeed,
          trigger: trigger,
          sessionsPerWeek: sessionsPerWeek,
          planScope: planScope,
          unlockedVariantByExerciseId: unlocked,
          carryOverByExerciseId: carryOvers,
          userSnapshot: {
            'fitness_level': profile['fitness_level'],
            'fork': fork,
            'goals': goals,
            'active_pain_areas': activePainAreas,
            'training_duration': profile['training_duration'],
            'schedule_sessions': sessionsPerWeek,
            'schedule_keys': schedule,
          },
        ),
      );

      await _insertRecommendationLog(result);
      await _rememberLatestRecommendationId(result.plan.recommendationId);
      return result;
    } catch (e) {
      debugPrint('[RecommendationService] plan generation failed: $e');
      return null;
    }
  }

  Future<Plan?> fetchLatestPlanForCurrentUser() async {
    final snapshot = await fetchLatestPlanSnapshotForCurrentUser();
    return snapshot?.plan;
  }

  Future<PlanSnapshot?> ensurePlanForCurrentUser({
    String trigger = 'onboarding',
    String planScope = kPlanScopeFull,
  }) async {
    final active = await fetchLatestActivePlanSnapshotForCurrentUser();
    if (active != null) return active;

    final result = await generatePlanForCurrentUser(
      trigger: trigger,
      planScope: planScope,
    );
    if (result == null) {
      return fetchLatestActivePlanSnapshotForCurrentUser();
    }
    return PlanSnapshot(
      plan: result.plan,
      generatedAt: DateTime.now(),
    );
  }

  Future<PlanSnapshot?> fetchLatestActivePlanSnapshotForCurrentUser() {
    return _fetchPlanSnapshotForCurrentUser(activeOnly: true);
  }

  Future<PlanSnapshot?> fetchLatestPlanSnapshotForCurrentUser() async {
    return _fetchPlanSnapshotForCurrentUser(activeOnly: false);
  }

  Future<Map<String, ExerciseLaunchCatalogInfo>>
      fetchLaunchCatalogInfoForExerciseIds(
    Iterable<String> exerciseIds,
  ) async {
    final ids = exerciseIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const {};

    String? cleanString(dynamic value) {
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    try {
      final rows = await _client
          .from('exercise_catalog')
          .select('id, english_name, class_key, is_form_checked')
          .inFilter('id', ids);

      return {
        for (final raw in rows as List)
          if ((raw as Map)['id'] is String)
            raw['id'] as String: ExerciseLaunchCatalogInfo(
              id: raw['id'] as String,
              englishName: cleanString(raw['english_name']),
              classKey: cleanString(raw['class_key']),
              isFormChecked: raw['is_form_checked'] == true,
            ),
      };
    } catch (e) {
      debugPrint('[RecommendationService] launch catalog fetch failed: $e');
      return const {};
    }
  }

  Future<PlanSnapshot?> _fetchPlanSnapshotForCurrentUser({
    required bool activeOnly,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _fetchLatestRecommendationRow(
        user.id,
        activeOnly: activeOnly,
      );
      if (row == null) return null;

      final plan = Plan.fromSupabase(
        recommendationId: row['id'] as String,
        userId: row['user_id'] as String,
        templateKey: row['template_key'] as String,
        planStructure: (row['plan_structure'] as Map).cast<String, dynamic>(),
      );

      final completionMap = await _sessions.completionMapForPlan(
        recommendationId: plan.recommendationId,
      );
      return PlanSnapshot(
        plan: plan,
        generatedAt: _dateTimeOrNull(row['generated_at']),
        startedAt: _dateTimeOrNull(row['plan_started_at']),
        completedAt: _dateTimeOrNull(row['plan_completed_at']),
        scheduleDayIndexes: _scheduleDayIndexesFromRow(row),
        completionMap: completionMap,
      );
    } catch (e) {
      debugPrint('[RecommendationService] latest plan fetch failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchLatestRecommendationRow(
    String userId, {
    bool activeOnly = false,
  }) async {
    const selectWithLifecycle =
        'id, user_id, generated_at, template_key, plan_structure, '
        'plan_started_at, plan_completed_at, user_snapshot, parameters';
    final canonicalRow = activeOnly
        ? await _client
            .from('recommendations_log')
            .select(selectWithLifecycle)
            .eq('user_id', userId)
            .filter('plan_completed_at', 'is', null)
            .order('generated_at', ascending: false)
            .limit(1)
            .maybeSingle()
        : await _client
            .from('recommendations_log')
            .select(selectWithLifecycle)
            .eq('user_id', userId)
            .order('generated_at', ascending: false)
            .limit(1)
            .maybeSingle();
    if (canonicalRow != null) {
      final cast = canonicalRow.cast<String, dynamic>();
      unawaited(_rememberLatestRecommendationId(cast['id'] as String));
      return cast;
    }

    final rememberedId = await _readLatestRecommendationId();

    if (rememberedId != null) {
      try {
        final row = await _client
            .from('recommendations_log')
            .select(selectWithLifecycle)
            .eq('user_id', userId)
            .eq('id', rememberedId)
            .maybeSingle();
        if (row != null) {
          final cast = row.cast<String, dynamic>();
          if (!activeOnly || cast['plan_completed_at'] == null) return cast;
        }
      } catch (_) {
        // Ignore stale local cache misses.
      }
    }

    return null;
  }

  Future<List<String>> _fetchActivePainAreas(String userId) async {
    try {
      final rows = await _client
          .from('user_pain_areas')
          .select('body_region')
          .eq('user_id', userId)
          .eq('status', 'active');
      return (rows as List)
          .map((row) => (row as Map<String, dynamic>)['body_region'] as String)
          .toList();
    } catch (e) {
      debugPrint('[RecommendationService] pain area fetch failed: $e');
      return const [];
    }
  }

  Future<List<String>> _fetchRecentExerciseIds(String userId) async {
    try {
      final rows = await _client
          .from('exercise_sessions')
          .select('exercise_id')
          .eq('user_id', userId)
          .order('completed_at', ascending: false)
          .limit(6);
      return (rows as List)
          .map((row) => (row as Map<String, dynamic>)['exercise_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('[RecommendationService] recent exercise fetch failed: $e');
      return const [];
    }
  }

  Future<void> _insertRecommendationLog(RecommendationResult result) async {
    await _client.from('recommendations_log').insert({
      'id': result.plan.recommendationId,
      'user_id': result.plan.userId,
      'template_key': result.plan.templateKey,
      'trigger': result.trigger,
      'algorithm_version': result.algorithmVersion,
      'rng_seed': result.rngSeed,
      'parameters': _parametersPayload(result),
      'user_snapshot': result.userSnapshot,
      'plan_structure': result.plan.toPlanStructureJson(),
    });
  }

  Map<String, dynamic> _parametersPayload(RecommendationResult result) {
    return {
      'fork': result.userSnapshot['fork'],
      'goals': result.userSnapshot['goals'],
      'fitness_level': result.userSnapshot['fitness_level'],
      'pain_areas': result.userSnapshot['active_pain_areas'],
      'training_duration': result.userSnapshot['training_duration'],
      'schedule_sessions': result.userSnapshot['schedule_keys'] ??
          result.userSnapshot['schedule_sessions'],
      'engine_parameters': result.parameters,
    };
  }

  Future<void> _rememberLatestRecommendationId(String recommendationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_latestRecommendationIdKey, recommendationId);
    } catch (_) {}
  }

  Future<String?> _readLatestRecommendationId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_latestRecommendationIdKey);
    } catch (_) {
      return null;
    }
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-'
        '${h.substring(20)}';
  }

  DateTime? _dateTimeOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<int> _scheduleDayIndexesFromRow(Map<String, dynamic> row) {
    final raw = _scheduleListFromPayload(row['user_snapshot']) ??
        _scheduleListFromPayload(row['parameters']);
    if (raw == null) return const [];

    final days = raw
        .map(_scheduleTokenToDayIndex)
        .whereType<int>()
        .where((day) => day >= 0 && day <= 6)
        .toSet()
        .toList()
      ..sort();
    return days;
  }

  List<dynamic>? _scheduleListFromPayload(dynamic payload) {
    if (payload is! Map) return null;
    final map = payload.cast<String, dynamic>();
    final scheduleKeys = map['schedule_keys'];
    if (scheduleKeys is List) return scheduleKeys;
    final scheduleSessions = map['schedule_sessions'];
    if (scheduleSessions is List) return scheduleSessions;
    return null;
  }

  int? _scheduleTokenToDayIndex(dynamic value) {
    final token = value.toString().trim().toUpperCase();
    final vietnamese = RegExp(r'^T([2-7])').firstMatch(token);
    if (vietnamese != null) {
      return int.parse(vietnamese.group(1)!) - 2;
    }
    if (token.startsWith('CN') || token.startsWith('SUN')) return 6;
    if (token.startsWith('MON')) return 0;
    if (token.startsWith('TUE')) return 1;
    if (token.startsWith('WED')) return 2;
    if (token.startsWith('THU')) return 3;
    if (token.startsWith('FRI')) return 4;
    if (token.startsWith('SAT')) return 5;
    return null;
  }
}

class PlanSnapshot {
  const PlanSnapshot({
    required this.plan,
    this.generatedAt,
    this.startedAt,
    this.completedAt,
    this.completionMap = const {},
    this.scheduleDayIndexes = const [],
  });

  final Plan plan;
  final DateTime? generatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<int> scheduleDayIndexes;
  final Map<int, Set<int>> completionMap;

  (int, int)? get currentPosition {
    if (plan.weeks.isEmpty) return null;
    if (completedAt != null) return null;

    for (final week in plan.weeks) {
      int weekNumber = week.weekNumber;
      final done = completionMap[weekNumber];
      for (final session in week.sessions) {
        if (done == null || !done.contains(session.sessionIndex)) {
          return (weekNumber, session.sessionIndex);
        }
      }
    }
    return null;
  }

  WeekPlan? get currentWeek {
    if (plan.weeks.isEmpty) return null;
    (int, int)? position = currentPosition;
    return plan.weeks.firstWhere(
      (week) => week.weekNumber == position?.$1,
      orElse: () => plan.weeks.last,
    );
  }
}

class ExerciseLaunchCatalogInfo {
  const ExerciseLaunchCatalogInfo({
    required this.id,
    required this.isFormChecked,
    this.vietnameseName,
    this.englishName,
    this.classKey,
  });

  final String id;
  final bool isFormChecked;
  final String? englishName;
  final String? vietnameseName;
  final String? classKey;

  Iterable<String> get lookupKeys sync* {
    final keys = [classKey, id, englishName];
    for (final key in keys) {
      final value = key?.trim();
      if (value != null && value.isNotEmpty) yield value;
    }
  }
}
