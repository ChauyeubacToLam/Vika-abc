import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeeklyCheckInQuestion {
  const WeeklyCheckInQuestion({
    required this.key,
    required this.vietnamesePrompt,
  });

  final String key;
  final String vietnamesePrompt;
}

class WeeklyCheckInAnswers {
  const WeeklyCheckInAnswers({
    required this.energy,
    required this.soreness,
    required this.sleep,
    required this.motivation,
    required this.painChange,
    required this.progressFeel,
  });

  final int energy;
  final int soreness;
  final int sleep;
  final int motivation;
  final String painChange;
  final String progressFeel;

  Map<String, dynamic> toResponsesJson() => {
        'energy': energy,
        'soreness': soreness,
        'sleep_quality': sleep,
        'motivation': motivation,
        'pain_change': painChange,
        'progress_feel': progressFeel,
      };
}

class WeeklyCheckInService {
  WeeklyCheckInService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const questions = [
    WeeklyCheckInQuestion(
      key: 'energy',
      vietnamesePrompt: 'Tuần này năng lượng của bạn thế nào?',
    ),
    WeeklyCheckInQuestion(
      key: 'soreness',
      vietnamesePrompt: 'Cơ thể còn đau mỏi nhiều không?',
    ),
    WeeklyCheckInQuestion(
      key: 'sleep',
      vietnamesePrompt: 'Giấc ngủ của bạn tuần này ổn chứ?',
    ),
    WeeklyCheckInQuestion(
      key: 'motivation',
      vietnamesePrompt: 'Bạn còn muốn tiếp tục lộ trình không?',
    ),
    WeeklyCheckInQuestion(
      key: 'pain_change',
      vietnamesePrompt: 'Vùng đau/căng có thay đổi không?',
    ),
    WeeklyCheckInQuestion(
      key: 'progress_feel',
      vietnamesePrompt: 'Bạn cảm thấy mình tiến bộ ra sao?',
    ),
  ];

  final SupabaseClient _client;

  Future<bool> isDue({
    required String recommendationId,
    required int weekNumber,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || weekNumber < 2) return false;

    try {
      final row = await _client
          .from('weekly_checkins')
          .select('id')
          .eq('user_id', user.id)
          .eq('recommendation_id', recommendationId)
          .eq('week_number', weekNumber)
          .maybeSingle();
      return row == null;
    } catch (e) {
      debugPrint('[WeeklyCheckIn] due check failed: $e');
      return false;
    }
  }

  Future<bool> submit({
    required String recommendationId,
    required int weekNumber,
    required WeeklyCheckInAnswers answers,
    int? phaseNumber,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client.from('weekly_checkins').upsert(
        {
          'user_id': user.id,
          'recommendation_id': recommendationId,
          'week_number': weekNumber,
          'phase_number': phaseNumber ?? _phaseNumberForWeek(weekNumber),
          'responses': answers.toResponsesJson(),
          'energy_score': answers.energy,
          'pain_flag': answers.painChange == 'worse',
        },
        onConflict: 'user_id,recommendation_id,week_number',
      );
      return true;
    } catch (e) {
      debugPrint('[WeeklyCheckIn] submit failed: $e');
      return false;
    }
  }
}

int _phaseNumberForWeek(int weekNumber) {
  if (weekNumber >= 7) return 3;
  if (weekNumber >= 4) return 2;
  return 1;
}
