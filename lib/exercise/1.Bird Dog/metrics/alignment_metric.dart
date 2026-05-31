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

    // 1. Lỗi căn chỉnh tay chân
    bool armBad = ctx.activeArmHorizontalAngle > 20.0;
    bool legBad = ctx.activeLegHorizontalAngle > 20.0;

    if (armBad || legBad) {
      if (!_faults.any((f) => f.type == 'Alignment_Limb')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Alignment_Limb',
          message: 'Tay/Chân duỗi chưa thẳng với mặt đất',
          voiceMessage: 'Vươn dài tay và chân ra',
          affectsForm: true,
          priority: BirdDogFaultPriority.alignment,
        ));
      }
    }

    // 2. Lỗi CÚI ĐẦU: So sánh trục Y của Tai và Vai. Y trong màn hình hướng xuống dưới.
    // Nếu Tai nằm thấp hơn Vai nhiều (tọa độ Y lớn hơn) -> Cúi gập cổ.
    if (ctx.scaleFactor != null) {
      if (ctx.earY > ctx.shoulderY + (ctx.scaleFactor! * 0.15)) {
        if (!_faults.any((f) => f.type == 'Alignment_Head')) {
          _faults.add(FaultRecord(
            phase: ctx.state.name,
            type: 'Alignment_Head',
            message: 'Đầu cúi quá thấp',
            voiceMessage: 'Nâng đầu lên, mắt nhìn xuống thảm',
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
  }
}
