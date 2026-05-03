import 'butterfly_metric_base.dart';

class HoldDurationMetric extends ButterflyMetricBase {
  @override
  String get name => 'HoldDuration';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  int? _holdStartMs;
  double currentHoldSeconds = 0.0;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(ButterflyState from, ButterflyState to, int timestampMs) {
    if (to == ButterflyState.isometric_hold) {
      _holdStartMs = timestampMs;
    } else if (from == ButterflyState.isometric_hold) {
      // Kết thúc hold, reset bộ đếm tạm thời
      _holdStartMs = null;
    }
  }

  @override
  void update(StretchContext ctx) {
    if (ctx.currentState == ButterflyState.isometric_hold && _holdStartMs != null) {
      currentHoldSeconds = (ctx.frameTimestamp - _holdStartMs!) / 1000.0;
      _debugData['hold_time'] = currentHoldSeconds.toStringAsFixed(1);
      
      // Update UI trực tiếp thông qua resultIssues (Live Feedback)
      ctx.resultIssues.feedback['Thời gian'] = '${currentHoldSeconds.toStringAsFixed(1)}s';
      
      // Chú ý: Cần một cơ chế (như Callback) để cộng dồn currentHoldSeconds 
      // vào biến totalValidHoldTime của lớp ButterflyStretch chính.
    }
  }

  @override
  void reset() {
    _holdStartMs = null;
    currentHoldSeconds = 0.0;
    _faults.clear();
  }
}