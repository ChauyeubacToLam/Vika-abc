import 'seated_forward_metric_base.dart';

class HoldTempoMetric extends SeatedForwardMetricBase {
  @override
  String get name => 'HoldTempo';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  int? _holdStartMs;
  double activeHoldSeconds = 0.0;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(SeatedForwardState from, SeatedForwardState to, int timestampMs) {
    if (to == SeatedForwardState.isometricHold) {
      _holdStartMs = timestampMs;
    } else if (from == SeatedForwardState.isometricHold) {
      flushCurrentSegment(timestampMs);
      _validateHoldTime();
    }
  }

  @override
  void update(SeatedForwardContext ctx) {
    if (ctx.state == SeatedForwardState.isometricHold && _holdStartMs != null) {
      final double currentHold = (ctx.frameTimestampMs - _holdStartMs!) / 1000.0;
      ctx.resultIssues.feedback['Time'] = '${(activeHoldSeconds + currentHold).toStringAsFixed(1)}s / ${SeatedForwardConfig.At_Min_Hold_Time}s';
    }
  }

  void flushCurrentSegment(int currentMs) {
    if (_holdStartMs != null) {
      activeHoldSeconds += (currentMs - _holdStartMs!) / 1000.0;
      _holdStartMs = null;
    }
  }

  void _validateHoldTime() {
    if (activeHoldSeconds < SeatedForwardConfig.At_Min_Hold_Time) {
      if (!_faults.any((f) => f.type == 'TempoShort')) {
        _faults.add(FaultRecord(
          phase: SeatedForwardState.isometricHold.name,
          type: 'TempoShort',
          message: 'Chưa đủ thời gian kéo giãn',
          voiceMessage: 'Cố gắng giữ lâu hơn để cơ kịp giãn ra',
          affectsForm: false,
          priority: SeatedForwardFaultVoicePriority.holdTempo,
        ));
      }
    }
  }

  @override
  void reset() {
    super.reset();
    _holdStartMs = null;
    activeHoldSeconds = 0.0;
  }
}