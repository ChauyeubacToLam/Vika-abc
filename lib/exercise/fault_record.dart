class FaultRecord {
  final String phase;
  final String type;
  final String message;
  final bool affectsForm;
  final String? voiceMessage;
  final int priority; // lower = higher priority

  FaultRecord({
    required this.phase,
    required this.type,
    required this.message,
    this.affectsForm = true,
    this.voiceMessage,
    this.priority = 99,
  });
}
