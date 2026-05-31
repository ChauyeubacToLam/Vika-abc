import 'bird_dog_metric_base.dart';

class TrunkStabilityMetric extends BirdDogMetricBase {
  @override
  String get name => 'TrunkStability';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _neutralHipY;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

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

    if (ctx.state == BirdDogState.hold_extended && ctx.scaleFactor != null) {
      // Sụt hông: Khoảng cách Y thay đổi > 15% độ dài thân
      double deviation = (ctx.hipY - _neutralHipY!).abs() / ctx.scaleFactor!;

      if (deviation > 0.15) {
        if (!_faults.any((f) => f.type == 'Trunk')) {
          _faults.add(FaultRecord(
            phase: ctx.state.name,
            type: 'Trunk',
            message: 'Hông bị lệch/sụt',
            voiceMessage: 'Gồng chặt cơ bụng, giữ hông cân bằng',
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
  }
}
