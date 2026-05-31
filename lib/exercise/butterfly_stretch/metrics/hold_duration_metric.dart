import 'butterfly_metric_base.dart';

/// Metric này KHÔNG tự quản lý thời gian hold.
/// ButterflyStretch là nguồn sự thật duy nhất cho _holdStartMs và totalValidHoldTime.
/// HoldDurationMetric chỉ nhận currentHoldSeconds qua StretchContext rồi lo việc
/// hiển thị và ghi debug — tránh race condition ghi đè feedback['Thời gian'].
class HoldDurationMetric extends ButterflyMetricBase {
  @override
  String get name => 'HoldDuration';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /// Không cần onStateTransition ở đây nữa — ButterflyStretch tự xử lý _holdStartMs.
  @override
  void onStateTransition(
      ButterflyState from, ButterflyState to, int timestampMs) {}

  @override
  void update(StretchContext ctx) {
    if (ctx.currentState != ButterflyState.isometric_hold) return;

    // currentHoldSeconds được ButterflyStretch tính sẵn và truyền vào ctx
    _debugData['hold_time'] = ctx.currentHoldSeconds.toStringAsFixed(1);

    // Metric này KHÔNG ghi feedback['Thời gian'] — việc đó do ButterflyStretch._updateHoldDisplay() lo,
    // tránh 2 nơi ghi đè nhau.
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
  }
}
