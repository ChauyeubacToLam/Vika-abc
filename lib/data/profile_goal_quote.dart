/// Motivational pull-quote for the Profile GoalCard, keyed off the user's
/// onboarding goal (profiles.goals[0]). Identity/process framed, no numbers,
/// compares to the user's past self, never a medical claim.
const Map<String, String> kGoalQuotes = {
  'health': 'Mỗi buổi tập là một ngày bạn chọn sống khoẻ hơn cho mình.',
  'body': 'Bạn đang dựng nên vóc dáng mình mong muốn, từng buổi một.',
  'strength': 'Mỗi buổi tập, bạn mạnh hơn chính mình của hôm qua.',
  'flexible': 'Cơ thể bạn dẻo dai hơn, tâm trí nhẹ nhõm hơn sau mỗi buổi.',
};

const String kGoalQuoteFallback =
    'Mỗi buổi tập đưa bạn gần hơn với người mình muốn trở thành.';

String goalQuoteFor(String? goal) => kGoalQuotes[goal] ?? kGoalQuoteFallback;
