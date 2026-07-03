/* =========================================================================
   Metric 3: Vertical Hip Oscillation (Biên độ dao động)
   Priority: 🟡 MEDIUM — Hiệu suất cơ liên sườn
   ========================================================================= */

import 'side_plank_dip_metric_base.dart';

class AmplitudeConfig {
  static const double SHALLOW_BOTTOM_ANGLE = 150.0; // Không chịu hạ xuống sâu
}

class HipAmplitudeMetric extends SidePlankDipMetricBase {
  @override
  String get name => 'HipAmplitude';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _minBodyAngle;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.plankState == SidePlankState.bottom ||
        ctx.plankState == SidePlankState.descending) {
      if (_minBodyAngle == null || ctx.bodyAngle < _minBodyAngle!) {
        _minBodyAngle = ctx.bodyAngle;
      }
    }
  }

  @override
  void onStateTransition(
      SidePlankState from, SidePlankState to, int timestampMs) {
    if (to == SidePlankState.top && _minBodyAngle != null) {
      if (_minBodyAngle! > AmplitudeConfig.SHALLOW_BOTTOM_ANGLE) {
        _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'Amplitude',
          message: 'Biên độ quá ngắn. Hãy hạ hông xuống sát sàn hơn!',
          affectsForm: false, // Lỗi hiệu suất, không hủy Rep
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _minBodyAngle = null;
  }
}
