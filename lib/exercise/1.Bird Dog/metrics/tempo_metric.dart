import 'bird_dog_metric_base.dart';

class TempoMetric extends BirdDogMetricBase {
  @override
  String get name => 'Tempo';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _holdStartMs;
  double? holdDuration;
  double? _liveHoldSeconds;

  int? get holdStartMs => _holdStartMs;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;
  @override
  double? get value => _liveHoldSeconds ?? holdDuration;
  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningBelow: BirdDogTiming.holdTargetSeconds,
      );
  @override
  MetricStatus get status {
    final seconds = value;
    if (seconds == null) return MetricStatus.pass;
    return seconds < BirdDogTiming.holdTargetSeconds
        ? MetricStatus.near
        : MetricStatus.pass;
  }

  @override
  void onStateTransition(BirdDogState from, BirdDogState to, int timestampMs) {
    if (to == BirdDogState.hold_extended) {
      _holdStartMs = timestampMs;
    } else if (from == BirdDogState.hold_extended && _holdStartMs != null) {
      holdDuration = (timestampMs - _holdStartMs!) / 1000.0;
    }
  }

  @override
  void update(BirdDogRepContext ctx) {
    if (ctx.state == BirdDogState.hold_extended && _holdStartMs != null) {
      _liveHoldSeconds = (ctx.frameTimestamp - _holdStartMs!) / 1000.0;
      _debugData['holdSeconds'] = _liveHoldSeconds;
      _debugData['holdTarget'] = BirdDogTiming.holdTargetSeconds;
    }
  }

  void evaluateRep(BirdDogRepContext ctx) {
    if (holdDuration != null &&
        holdDuration! < BirdDogTiming.holdTargetSeconds) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'Tempo',
        message:
            'Giữ chưa đủ ${BirdDogTiming.holdTargetShortLabel} (${holdDuration!.toStringAsFixed(1)}s)',
        voiceMessage:
            'Giữ ${BirdDogTiming.holdTargetVoiceLabel} ở điểm cao nhất.',
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
    _liveHoldSeconds = null;
    _debugData.clear();
  }
}
