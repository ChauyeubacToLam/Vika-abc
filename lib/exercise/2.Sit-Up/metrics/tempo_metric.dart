import 'sit_up_metric_base.dart';

class TempoMetric extends SitUpMetricBase {
  @override
  String get name => 'Tempo';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _loweringStartMs;
  double? loweringDuration;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(SitUpState from, SitUpState to, int timestampMs) {
    if (to == SitUpState.lowering) {
      _loweringStartMs = timestampMs;
    } else if (to == SitUpState.lying && _loweringStartMs != null) {
      loweringDuration = (timestampMs - _loweringStartMs!) / 1000.0;
    }
  }

  @override
  void update(SitUpRepContext ctx) {}

  // FIX: Bỏ param ctx — hàm chỉ dùng loweringDuration đã được tính qua onStateTransition()
  void evaluateRep() {
    // Lowering speed is intentionally unrestricted. Keep measuring the
    // duration for the session report, but never turn it into a form fault or
    // a voice correction.
  }

  @override
  void reset() {
    _faults.clear();
    _loweringStartMs = null;
    loweringDuration = null;
  }
}
