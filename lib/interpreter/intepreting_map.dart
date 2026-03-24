class IssueDefinition {
  final int priority;
  final List<String> questions;

  IssueDefinition({required this.priority, required this.questions});
}

Map<String, IssueDefinition> interpretingMap = {
  "heel_rise": IssueDefinition(
    priority: 0,
    questions: ["Bạn có thể ngồi xổm gót chân chạm đất không?"],
  ),
  "shallow_depth": IssueDefinition(
    priority: 1,
    questions: ["Khi squat bạn có thấy hông hoặc bắp chân căng không?"],
  ),
};
