import 'dead_bug_metric_base.dart';

class CoordinationMetric extends DeadBugMetricBase {
  @override
  String get name => 'Coordination';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  bool _evaluatedThisRep = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(DeadBugRepContext ctx) {
    if ((ctx.state == DeadBugState.extending || ctx.state == DeadBugState.hold) && !_evaluatedThisRep) {
      
      // Ngưỡng 125 độ để xác định chi đó đang được duỗi ra
      bool lArmExt = ctx.leftArmAngle > 125.0;
      bool rArmExt = ctx.rightArmAngle > 125.0;
      bool lHipExt = ctx.leftHipAngle > 125.0;
      bool rHipExt = ctx.rightHipAngle > 125.0;

      // Lỗi đi cùng bên (Left-Left hoặc Right-Right)
      bool sameSideLeft = lArmExt && lHipExt;
      bool sameSideRight = rArmExt && rHipExt;

      if (sameSideLeft || sameSideRight) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Coordination',
          message: 'Chuyển động cùng bên',
          voiceMessage: 'Sai nhịp! Hãy hạ tay và chân ĐỐI DIỆN nhau.',
          affectsForm: true,
          priority: DeadBugFaultPriority.coordination,
        ));
        _evaluatedThisRep = true;
      }
      
      // Chuyển động chéo chính xác
      bool crossLeftRight = lArmExt && rHipExt;
      bool crossRightLeft = rArmExt && lHipExt;
      
      if (crossLeftRight || crossRightLeft) {
        _evaluatedThisRep = true; // Đúng form, chốt sổ rep này
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _evaluatedThisRep = false;
  }
}