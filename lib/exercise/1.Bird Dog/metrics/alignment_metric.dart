import 'bird_dog_metric_base.dart';

class AlignmentMetric extends BirdDogMetricBase {
  @override
  String get name => 'Alignment';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(BirdDogRepContext ctx) {
    if (ctx.state != BirdDogState.hold_extended) return;

    // Góc lệch so với phương ngang > 20 độ
    bool armBad = ctx.activeArmHorizontalAngle > 20.0;
    bool legBad = ctx.activeLegHorizontalAngle > 20.0;

    if (armBad || legBad) {
      if (!_faults.any((f) => f.type == 'Alignment')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Alignment',
          message: 'Tay/Chân duỗi chưa thẳng với mặt đất',
          voiceMessage: 'Vươn dài tay và chân ra',
          affectsForm: true,
          priority: BirdDogFaultPriority.alignment,
        ));
      }
    }
  }

  @override
  void reset() => _faults.clear();
}