import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  })  : _client = client ?? Supabase.instance.client,
        _engine = engine ?? const RecommendationEngine(),
        _progression = progressionService ??
            RecommendationProgressionService(client: client);

  final SupabaseClient _client;
  final RecommendationEngine _engine;
  final RecommendationProgressionService _progression;
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
            'fitness_level, fork, goals, why_primary, training_duration, schedule_sessions',
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
            'why_primary': profile['why_primary'],
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
      return PlanSnapshot(
        plan: plan,
        generatedAt: _dateTimeOrNull(row['generated_at']),
        startedAt: _dateTimeOrNull(row['plan_started_at']),
        completedAt: _dateTimeOrNull(row['plan_completed_at']),
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
        'id, user_id, generated_at, template_key, plan_structure, plan_started_at, plan_completed_at';
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
        // Fall through to the canonical generated_at lookup below.
      }
    }

    final row = activeOnly
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
    return row?.cast<String, dynamic>();
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
}

class PlanSnapshot {
  const PlanSnapshot({
    required this.plan,
    this.generatedAt,
    this.startedAt,
    this.completedAt,
  });

  final Plan plan;
  final DateTime? generatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  int get currentWeekNumber {
    if (plan.weeks.isEmpty) return 1;
    if (completedAt != null) return plan.weeks.last.weekNumber;
    final anchor = startedAt ?? generatedAt;
    if (anchor == null) return 1;
    final days = DateTime.now().difference(anchor).inDays;
    final week = (days ~/ 7) + 1;
    return week.clamp(1, plan.weeks.length).toInt();
  }

  WeekPlan? get currentWeek {
    if (plan.weeks.isEmpty) return null;
    return plan.weeks.firstWhere(
      (week) => week.weekNumber == currentWeekNumber,
      orElse: () => plan.weeks.first,
    );
  }
}
