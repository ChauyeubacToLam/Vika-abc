import 'leg_raise_metric_base.dart';

class TempoMetric extends LegRaiseMetricBase {
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
  void onStateTransition(LegRaiseState from, LegRaiseState to, int timestampMs) {
    if (to == LegRaiseState.lowering) {
      _loweringStartMs = timestampMs;
    } else if (to == LegRaiseState.lying && _loweringStartMs != null) {
      loweringDuration = (timestampMs - _loweringStartMs!) / 1000.0;
    }
  }

  @override
  void update(LegRaiseRepContext ctx) {}

  void evaluateRep(LegRaiseRepContext ctx) {
    // Nếu rớt tự do < TEMPO_FAULT_THRESHOLD (ví dụ < 2.0s)
    if (loweringDuration != null && loweringDuration! < LegRaiseConfig.TEMPO_FAULT_THRESHOLD) {
       _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'Tempo',
          message: 'Thả rơi chân quá nhanh (${loweringDuration!.toStringAsFixed(1)}s)',
          voiceMessage: 'Từ từ thôi! Hạ chân chậm lại để giữ an toàn cho thắt lưng!',
          affectsForm: true,
          priority: LegRaiseFaultPriority.tempo,
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