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
    if (loweringDuration != null && loweringDuration! < 1.5) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'Tempo',
        message:
            'Hạ người quá nhanh (${loweringDuration!.toStringAsFixed(1)}s)',
        voiceMessage: 'Hạ lưng xuống chậm lại, cảm nhận cơ bụng căng ra',
        affectsForm: true,
        priority: SitUpFaultPriority.tempo,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _loweringStartMs = null;
    loweringDuration = null;
  }
}
