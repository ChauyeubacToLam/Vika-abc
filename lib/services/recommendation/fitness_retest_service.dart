import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/exercise_logger.dart';
import 'fitness_test_scoring.dart';
import 'models/plan.dart';

class FitnessRetestResult {
  const FitnessRetestResult({
    required this.squatLogger,
    this.wallPushupLogger,
    this.scoringInput,
  });

  final ExerciseLogger squatLogger;
  final ExerciseLogger? wallPushupLogger;
  final FitnessTestScoringInput? scoringInput;

  int get squatReps => squatLogger.repLogs.length;
  int get wallPushupReps => wallPushupLogger?.repLogs.length ?? 0;
  int? get squatFormScore => _formScore(squatLogger);
  int? get wallPushupFormScore => _formScore(wallPushupLogger);
}

class FitnessRetestSuggestion {
  const FitnessRetestSuggestion({
    required this.previousLevel,
    required this.suggestedLevel,
    required this.shouldPromptUser,
  });

  final String previousLevel;
  final String suggestedLevel;
  final bool shouldPromptUser;
}

class FitnessRetestService {
  FitnessRetestService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const vietnameseTitle = 'Kiểm tra lại thể lực';
  static const vietnameseDescription =
      'Làm lại bài kiểm tra 5 rep để Vika cập nhật cấp độ.';

  final SupabaseClient _client;

  Future<PendingFitnessRetest?> fetchPendingRetestForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _fetchLatestRecommendationRow(user.id);
      if (row == null) return null;

      final plan = Plan.fromSupabase(
        recommendationId: row['id'] as String,
        userId: row['user_id'] as String,
        templateKey: row['template_key'] as String,
        planStructure: (row['plan_structure'] as Map).cast<String, dynamic>(),
      );
      if (plan.endOfPlanRetest == null || plan.weeks.isEmpty) return null;

      final isRetestDay = _isOnOrAfterRetestDay(
        generatedAt: _dateTimeOrNull(row['generated_at']),
        totalWeeks: plan.weeks.length,
      );
      if (!isRetestDay) return null;

      final existing = await _client
          .from('fitness_retests')
          .select('id')
          .eq('user_id', user.id)
          .eq('recommendation_id', row['id'])
          .limit(1)
          .maybeSingle();
      if (existing != null) return null;

      return PendingFitnessRetest(
        recommendationId: row['id'] as String,
        plan: plan,
        weekNumber: plan.weeks.last.weekNumber,
      );
    } catch (e) {
      debugPrint('[FitnessRetest] pending fetch failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchLatestRecommendationRow(
    String userId,
  ) async {
    const selectWithLifecycle =
        'id, user_id, generated_at, template_key, plan_structure, plan_completed_at';
    final row = await _client
        .from('recommendations_log')
        .select(selectWithLifecycle)
        .eq('user_id', userId)
        .order('generated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?.cast<String, dynamic>();
  }

  FitnessRetestSuggestion suggestLevel({
    required String previousLevel,
    required FitnessRetestResult result,
    required String? trainingDuration,
    required String? fork,
  }) {
    final input = result.scoringInput ??
        FitnessTestScoringInput.fromSquatLogger(
          logger: result.squatLogger,
          trainingDuration: trainingDuration,
          fork: fork,
        );
    final suggested = FitnessTestScorer.score(input).suggestedLevel;
    return FitnessRetestSuggestion(
      previousLevel: previousLevel,
      suggestedLevel: suggested,
      shouldPromptUser: suggested != previousLevel,
    );
  }

  Future<SubmittedFitnessRetest?> submitRetest({
    required String recommendationId,
    required FitnessRetestResult result,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await _client
          .from('profiles')
          .select('fitness_level, training_duration, fork')
          .eq('id', user.id)
          .maybeSingle();
      final previousLevel =
          (profile?['fitness_level'] as String?) ?? 'beginner';
      final scoringInput = result.scoringInput ??
          FitnessTestScoringInput.fromSquatLogger(
            logger: result.squatLogger,
            trainingDuration: profile?['training_duration'] as String?,
            fork: profile?['fork'] as String?,
          );
      final suggestion = suggestLevel(
        previousLevel: previousLevel,
        result: FitnessRetestResult(
          squatLogger: result.squatLogger,
          wallPushupLogger: result.wallPushupLogger,
          scoringInput: scoringInput,
        ),
        trainingDuration: profile?['training_duration'] as String?,
        fork: profile?['fork'] as String?,
      );

      final row = await _client
          .from('fitness_retests')
          .insert({
            'user_id': user.id,
            'recommendation_id': recommendationId,
            'squat_reps': result.squatReps,
            'wall_pushup_reps': result.wallPushupReps,
            'squat_form_score': result.squatFormScore,
            'pushup_form_score': result.wallPushupFormScore,
            'previous_level': previousLevel,
            'suggested_level': suggestion.suggestedLevel,
            'accepted_level':
                suggestion.shouldPromptUser ? null : suggestion.suggestedLevel,
            'user_action': suggestion.shouldPromptUser ? null : 'no_change',
            'scoring_version': 'v1',
            'raw_scoring_input': scoringInput.toJson(),
          })
          .select('id')
          .single();

      return SubmittedFitnessRetest(
        retestId: row['id'] as String,
        suggestion: suggestion,
      );
    } catch (e) {
      debugPrint('[FitnessRetest] submit failed: $e');
      return null;
    }
  }

  Future<bool> confirmSuggestedLevel({
    required String retestId,
    required String suggestedLevel,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client.from('profiles').update({
        'fitness_level': suggestedLevel,
      }).eq('id', user.id);
      await _client
          .from('fitness_retests')
          .update({
            'accepted_level': suggestedLevel,
            'user_action': 'accepted',
          })
          .eq('id', retestId)
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      debugPrint('[FitnessRetest] confirm failed: $e');
      return false;
    }
  }

  Future<bool> declineSuggestedLevel(String retestId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client
          .from('fitness_retests')
          .update({
            'user_action': 'declined',
          })
          .eq('id', retestId)
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      debugPrint('[FitnessRetest] decline failed: $e');
      return false;
    }
  }

  bool _isOnOrAfterRetestDay({
    required DateTime? generatedAt,
    required int totalWeeks,
  }) {
    if (generatedAt == null) return false;
    if (totalWeeks < 1) return false;

    final generatedLocal = generatedAt.toLocal();
    final planStartDay = DateTime(
      generatedLocal.year,
      generatedLocal.month,
      generatedLocal.day,
    );
    final finalPlanDay = planStartDay.add(
      Duration(days: (totalWeeks * 7) - 1),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(finalPlanDay);
  }

  DateTime? _dateTimeOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

int? _formScore(ExerciseLogger? logger) {
  if (logger == null || logger.repLogs.isEmpty) return null;
  final good = (logger.setLogs['good_rep_count'] as num?)?.toInt() ??
      logger.repLogs.where((rep) => rep.correctForm).length;
  return ((good / logger.repLogs.length) * 100).round();
}

class PendingFitnessRetest {
  const PendingFitnessRetest({
    required this.recommendationId,
    required this.plan,
    required this.weekNumber,
  });

  final String recommendationId;
  final Plan plan;
  final int weekNumber;
}

class SubmittedFitnessRetest {
  const SubmittedFitnessRetest({
    required this.retestId,
    required this.suggestion,
  });

  final String retestId;
  final FitnessRetestSuggestion suggestion;
}
