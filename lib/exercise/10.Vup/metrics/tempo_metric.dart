import 'v_up_metric_base.dart';

class TempoMetric extends VUpMetricBase {
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
  void onStateTransition(VUpState from, VUpState to, int timestampMs) {
    if (to == VUpState.lowering) {
      _loweringStartMs = timestampMs;
    } else if (to == VUpState.lying && _loweringStartMs != null) {
      loweringDuration = (timestampMs - _loweringStartMs!) / 1000.0;
    }
  }

  @override
  void update(VUpRepContext ctx) {}

  void evaluateRep(VUpRepContext ctx) {
    // Không được thả rơi thân người và chân
    if (loweringDuration != null && loweringDuration! < 1.0) {
       _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'Tempo',
          message: 'Thả rơi tự do ở pha hạ (${loweringDuration!.toStringAsFixed(1)}s)',
          voiceMessage: 'Hạ chậm lại! Việc nhả cơ chậm sẽ xây dựng cơ bụng rất tốt.',
          affectsForm: true,
          priority: VUpFaultPriority.tempo,
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