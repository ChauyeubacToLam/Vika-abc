import 'bird_dog_metric_base.dart';

class TempoMetric extends BirdDogMetricBase {
  @override
  String get name => 'Tempo';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _holdStartMs;
  double? holdDuration;

  int? get holdStartMs => _holdStartMs;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(BirdDogState from, BirdDogState to, int timestampMs) {
    if (to == BirdDogState.hold_extended) {
      _holdStartMs = timestampMs;
    } else if (from == BirdDogState.hold_extended && _holdStartMs != null) {
      holdDuration = (timestampMs - _holdStartMs!) / 1000.0;
    }
  }

  @override
  void update(BirdDogRepContext ctx) {}

  void evaluateRep(BirdDogRepContext ctx) {
    if (holdDuration != null && holdDuration! < 5.0) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'Tempo',
        message: 'Giữ chưa đủ 5s (${holdDuration!.toStringAsFixed(1)}s)',
        voiceMessage: 'Giữ lại 5 giây ở điểm cao nhất nhé',
        affectsForm: true,
        priority: BirdDogFaultPriority.tempo,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _holdStartMs = null;
    holdDuration = null;
  }
}
