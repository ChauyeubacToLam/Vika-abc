import 'dead_bug_metric_base.dart';

class CoordinationMetric extends DeadBugMetricBase {
  @override
  String get name => 'Coordination';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  bool _evaluatedThisRep = false;
  bool? _lastWasLeftArm;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(DeadBugRepContext ctx) {
    if ((ctx.state == DeadBugState.extending ||
            ctx.state == DeadBugState.hold) &&
        !_evaluatedThisRep) {
      bool sameSide =
          ctx.physicalLeftArmExtending == ctx.physicalLeftLegExtending;

      if (sameSide) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Coordination',
          message: 'Chuyển động cùng bên',
          voiceMessage: 'Sai nhịp! Hãy hạ tay và chân ĐỐI DIỆN nhau.',
          affectsForm: true,
          priority: DeadBugFaultPriority.coordination,
        ));
        _evaluatedThisRep = true;
      } else {
        // Chuyển động chéo chính xác (Khác bên)
        bool currentIsLeftArm = ctx.physicalLeftArmExtending;
        if (_lastWasLeftArm != null && _lastWasLeftArm == currentIsLeftArm) {
          _faults.add(FaultRecord(
            phase: ctx.state.name,
            type: 'NotAlternating',
            message: 'Không luân phiên đổi bên',
            voiceMessage: 'Nhớ đổi bên sau mỗi lần nhé',
            affectsForm: true,
            priority: DeadBugFaultPriority.coordination,
          ));
        }
        _lastWasLeftArm = currentIsLeftArm;
        _evaluatedThisRep = true;
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _evaluatedThisRep = false;
  }
}
