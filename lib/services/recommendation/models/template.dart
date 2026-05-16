import 'slot.dart';

// Compile-time const template definition. The 8 launch templates
// live in lib/services/recommendation/templates.dart as a const Map.
//
// ArchetypeRouter selects ONE template per user based on (fork, goal).
// The selected template's slots define what the RecommendationEngine
// fills each session.

class Template {
  const Template({
    required this.key,
    required this.fork,
    required this.goal,
    required this.vietnameseName,
    required this.slots,
    required this.phaseNames,
  });

  /// Stable identifier persisted to recommendations_log.template_key.
  /// e.g. 'home_strength', 'yoga_pain'.
  final String key;

  /// 'home' | 'yoga'. No 'both' for templates — every user is in
  /// exactly one fork. ExerciseCatalogEntry.fork='both' just means
  /// the exercise can appear in either fork's templates.
  final String fork;

  /// Goal key matching ScoringService's goal vocabulary.
  /// See ExerciseCatalogEntry.goalFit doc note about the
  /// why_primary → goal mapping at ScoringService.
  final String goal;

  /// User-facing template display name, e.g. 'Tập tạ — Khoẻ hơn'.
  /// Shown in places where users see "your program is X".
  final String vietnameseName;

  /// Ordered list of slots. Each session in the plan fills these
  /// slots in order. Typical length 4.
  final List<Slot> slots;

  /// One phase name per week of the plan. Length should match
  /// the program's week count (4 for v1).
  /// e.g. ['Khởi đầu', 'Củng cố', 'Đẩy mạnh', 'Đánh giá lại'].
  final List<String> phaseNames;
}
