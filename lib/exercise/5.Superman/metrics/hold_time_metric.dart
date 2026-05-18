import 'superman_metric_base.dart';

class HoldTimeMetric extends SupermanMetricBase {
  @override
  String get name => 'HoldTime';

  int? _holdStartMs;
  double lastHoldDurationMs = 0;

  @override
  void onStateTransition(SupermanState from, SupermanState to, int timestampMs) {
    if (to == SupermanState.hold) {
      _holdStartMs = timestampMs;
    } else if (from == SupermanState.hold && _holdStartMs != null) {
      lastHoldDurationMs = (timestampMs - _holdStartMs!).toDouble();
      _holdStartMs = null;
    }
  }

  @override
  void update(SupermanRepContext ctx) {
    if (_holdStartMs != null) {
      debugData['hold_time_ms'] = ctx.frameTimestampMs - _holdStartMs!;
    }
  }

  @override
  void evaluateRepEnd(SupermanRepContext ctx) {
    if (lastHoldDurationMs < SupermanConfig.HOLD_MIN_MS) {
      addFault(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'HoldTooShort',
        message: 'Giữ tư thế lâu hơn!',
        voiceMessage: 'Giữ lại 2 giây ở điểm cao nhất, không giật cục',
        affectsForm: false,
        priority: SupermanVoicePriority.holdTime,
      ));
    }
  }
}