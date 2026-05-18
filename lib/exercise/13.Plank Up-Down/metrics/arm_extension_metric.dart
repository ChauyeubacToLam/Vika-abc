import 'plank_up_down_metric_base.dart';

class ArmExtensionMetric extends PlankMetricBase {
  @override
  String get name => 'Arm Extension';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  bool _reachedFullExtension = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(PlankRepContext ctx) {
    if (ctx.currentState == PlankState.high_plank && ctx.elbowAngle >= PlankConfig.ELBOW_HIGH_PLANK_MIN) {
      _reachedFullExtension = true;
    }
  }

  @override
  void onStateTransition(PlankState from, PlankState to, int timestampMs) {
    // Nếu từ High Plank về Lowering mà chưa duỗi thẳng tay
    if (from == PlankState.high_plank && to == PlankState.lowering) {
      if (!_reachedFullExtension) {
        _faults.add(FaultRecord(
          phase: 'high_plank',
          type: 'ArmExtension',
          message: 'Chưa duỗi thẳng tay ở High Plank',
          affectsForm: true,
          voiceMessage: 'Đẩy thẳng tay lên!',
          priority: PlankFaultVoicePriority.armExtension,
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _reachedFullExtension = false;
  }
}