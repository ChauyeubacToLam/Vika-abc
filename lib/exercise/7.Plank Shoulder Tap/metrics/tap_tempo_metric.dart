import 'plank_shoulder_tap_metric_base.dart';

class TapTempoMetric extends PlankTapMetricBase {
  @override
  String get name => 'TapTempo';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _liftStartMs;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(PlankTapState from, PlankTapState to, int timestampMs) {
    if (from == PlankTapState.base && to == PlankTapState.lifting) {
      _liftStartMs = timestampMs;
    }
  }

  @override
  void update(RepContext ctx) {
    if (_liftStartMs != null && ctx.state != PlankTapState.base) {
      double elapsed = (ctx.frameTimestamp - _liftStartMs!) / 1000.0;
      _debugData['timeIn3PointStance'] = elapsed.toStringAsFixed(2);
    }
  }

  @override
  void evaluateRepEnd(RepContext ctx) {
    if (_liftStartMs != null) {
      double totalLiftTime = (ctx.frameTimestamp - _liftStartMs!) / 1000.0;
      if (totalLiftTime < PlankTapConfig.MIN_TAP_TIME) {
        _faults.add(FaultRecord(
          phase: 'RETURNING', type: 'TooFast', message: 'Tập giật cục, quá nhanh',
          affectsForm: false, priority: PlankTapVoicePriority.tempo, voiceMessage: 'Chậm lại! Kiểm soát nhịp độ khi nhấc tay'
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _liftStartMs = null;
  }
}