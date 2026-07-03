import 'bird_dog_metric_base.dart';

class TrunkStabilityMetric extends BirdDogMetricBase {
  @override
  String get name => 'TrunkStability';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _neutralHipY;
  double? _hipDeviation;
  MetricStatus _status = MetricStatus.pass;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;
  @override
  double? get value => _hipDeviation;
  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: 0.10,
        faultAbove: 0.15,
      );
  @override
  MetricStatus get status => _status;

  @override
  void onStateTransition(BirdDogState from, BirdDogState to, int timestampMs) {
    // Lưu vị trí hông lúc chuẩn bị
    if (to == BirdDogState.extending) {
      _neutralHipY = null; // Khởi tạo lại
    }
  }

  @override
  void update(BirdDogRepContext ctx) {
    _neutralHipY ??= ctx.hipY;

    final scale = ctx.scaleFactor;
    if (scale != null && scale.isFinite && scale > 1e-6) {
      // Sụt hông: Khoảng cách Y thay đổi > 15% độ dài thân
      double deviation = (ctx.hipY - _neutralHipY!).abs() / scale;
      _hipDeviation = deviation;
      _status = deviation > 0.15
          ? MetricStatus.fault
          : deviation > 0.10
              ? MetricStatus.near
              : MetricStatus.pass;
      _debugData['hipDeviation'] = deviation;
      _debugData['neutralHipY'] = _neutralHipY;
      _debugData['hipY'] = ctx.hipY;

      if (ctx.state != BirdDogState.hold_extended) return;

      if (deviation > 0.15) {
        if (!_faults.any((f) => f.type == 'Trunk')) {
          _faults.add(FaultRecord(
            phase: ctx.state.name,
            type: 'Trunk',
            message: 'Hông bị lệch/sụt',
            voiceMessage: 'Siết bụng, giữ hông cân bằng.',
            affectsForm: true,
            priority: BirdDogFaultPriority.trunkStability,
          ));
        }
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _neutralHipY = null;
    _debugData.clear();
    _hipDeviation = null;
    _status = MetricStatus.pass;
  }
}
