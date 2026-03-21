class IssueDefinition {
  final int priority;
  final List<String> questions;

  IssueDefinition({required this.priority, required this.questions});
}

Map<String, IssueDefinition> interpretingMap = {
  "heel_rise": IssueDefinition(
    priority: 1,
    questions: ["Bạn có thể ngồi xổm gót chân chạm đất không?"],
  ),
};
