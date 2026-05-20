import 'lying_leg_raise_metric_base.dart';

class EccentricLoweringTempoMetric extends LyingLegRaiseMetricBase {
  @override
  String get name => 'LoweringTempo';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _loweringStartMs;
  double? _lastLoweringTime;

  double? get lastLoweringTime => _lastLoweringTime;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(LyingLegRaiseState from, LyingLegRaiseState to, int timestampMs) {
    if (to == LyingLegRaiseState.lowering) {
      _loweringStartMs = timestampMs;
    } else if (from == LyingLegRaiseState.lowering && _loweringStartMs != null) {
      _lastLoweringTime = (timestampMs - _loweringStartMs!) / 1000.0;
    }
  }

  @override
  void update(RepContext ctx) {
    if (_loweringStartMs != null && ctx.state == LyingLegRaiseState.lowering) {
      double currentTempo = (ctx.frameTimestamp - _loweringStartMs!) / 1000.0;
      _debugData['loweringTime'] = currentTempo.toStringAsFixed(2);
      ctx.resultIssues.feedback['Tempo'] = 'Kiểm soát, hạ từ từ...';
    } else {
      ctx.resultIssues.feedback.remove('Tempo');
    }
  }

  @override
  void evaluateRepEnd(RepContext ctx) {
    if (_lastLoweringTime != null && _lastLoweringTime! < LegRaiseConfig.ECCENTRIC_MIN_TIME) {
      _faults.add(FaultRecord(
        phase: 'LOWERING', type: 'FastEccentric', message: 'Thả chân rầm xuống sàn',
        affectsForm: false, priority: LegRaiseVoicePriority.eccentricTempo, 
        voiceMessage: 'Cơ bụng mạnh nhất là khi hạ chân. Hãy gồng lại, hạ thật chậm!'
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _loweringStartMs = null;
    _lastLoweringTime = null;
  }
}