import 'reverse_crunch_metric_base.dart';

class EccentricTempoMetric extends ReverseCrunchMetricBase {
  @override
  String get name => 'EccentricTempo';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _loweringStartMs;
  double? loweringDuration;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(
      ReverseCrunchState from, ReverseCrunchState to, int timestampMs) {
    if (to == ReverseCrunchState.lowering) {
      _loweringStartMs = timestampMs;
    }
  }

  @override
  void update(RepContext ctx) {
    if (_loweringStartMs != null && ctx.state == ReverseCrunchState.lowering) {
      double currentLoweringTime =
          (ctx.frameTimestamp - _loweringStartMs!) / 1000.0;
      _debugData['loweringTime'] = currentLoweringTime.toStringAsFixed(2);
      ctx.resultIssues.feedback['Tempo'] = 'Từ từ hạ xuống...';
    }
  }

  @override
  void evaluateRepEnd(RepContext ctx) {
    if (_loweringStartMs != null) {
      loweringDuration = (ctx.frameTimestamp - _loweringStartMs!) / 1000.0;
      if (loweringDuration! < ReverseCrunchConfig.ECCENTRIC_MIN_TIME) {
        _faults.add(FaultRecord(
            phase: 'LOWERING',
            type: 'tempo',
            message: 'Hạ hông quá nhanh',
            affectsForm: false, // Lỗi nhịp độ, không đánh hỏng form cứng
            priority: CrunchVoicePriority.tempo,
            voiceMessage: 'Hạ hông từ từ có kiểm soát, đừng thả rơi tự do!'));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _loweringStartMs = null;
    loweringDuration = null;
  }
}
