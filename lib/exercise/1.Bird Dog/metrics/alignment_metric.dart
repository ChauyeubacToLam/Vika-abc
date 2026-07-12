import 'bird_dog_metric_base.dart';

class AlignmentMetric extends BirdDogMetricBase {
  @override
  String get name => 'Alignment';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  double? _limbDeviation;
  MetricStatus _status = MetricStatus.pass;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;
  @override
  double? get value => _limbDeviation;
  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: 25.0,
        faultAbove: 35.0,
      );
  @override
  MetricStatus get status => _status;

  @override
  void update(BirdDogRepContext ctx) {
    // 1. Lỗi căn chỉnh tay chân
    bool armBad = ctx.activeArmHorizontalAngle > 35.0;
    bool legBad = ctx.activeLegHorizontalAngle > 35.0;

    _limbDeviation = ctx.activeArmHorizontalAngle > ctx.activeLegHorizontalAngle
        ? ctx.activeArmHorizontalAngle
        : ctx.activeLegHorizontalAngle;
    _status = armBad || legBad
        ? MetricStatus.fault
        : _limbDeviation! > 25.0
            ? MetricStatus.near
            : MetricStatus.pass;
    _debugData['armHorizontal'] = ctx.activeArmHorizontalAngle;
    _debugData['legHorizontal'] = ctx.activeLegHorizontalAngle;
    _debugData['limbDeviation'] = _limbDeviation;

    if (ctx.state != BirdDogState.hold_extended) return;

    if (armBad || legBad) {
      if (!_faults.any((f) => f.type == 'alignment')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'alignment',
          message: 'Tay/Chân duỗi chưa thẳng với mặt đất',
          voiceMessage: 'Vươn dài tay và chân.',
          affectsForm: true,
          priority: BirdDogFaultPriority.alignment,
        ));
      }
    }

    // 2. Lỗi CÚI ĐẦU: So sánh trục Y của Tai và Vai. Y trong màn hình hướng xuống dưới.
    // Nếu Tai nằm thấp hơn Vai nhiều (tọa độ Y lớn hơn) -> Cúi gập cổ.
    if (ctx.scaleFactor != null) {
      final headDrop = (ctx.earY - ctx.shoulderY) / ctx.scaleFactor!;
      _debugData['headDrop'] = headDrop;
      if (headDrop > 0.15) {
        _status = MetricStatus.fault;
        if (!_faults.any((f) => f.type == 'head')) {
          _faults.add(FaultRecord(
            phase: ctx.state.name,
            type: 'head',
            message: 'Đầu cúi quá thấp',
            voiceMessage: 'Nâng đầu nhẹ, mắt nhìn xuống thảm.',
            affectsForm: true,
            priority: BirdDogFaultPriority.alignment,
          ));
        }
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _limbDeviation = null;
    _status = MetricStatus.pass;
  }
}
