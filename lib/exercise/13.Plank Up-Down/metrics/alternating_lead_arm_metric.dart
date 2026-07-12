import 'plank_up_down_metric_base.dart';

class AlternatingLeadArmMetric extends PlankMetricBase {
  @override
  String get name => 'Alternating Lead Arm';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int leftLeadCount = 0;
  int rightLeadCount = 0;
  String? lastLeadArm;
  String? currentLeadArm;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(PlankRepContext ctx) {
    if (ctx.currentState == PlankState.pushing_up && currentLeadArm == null) {
      detectLeadArm(ctx.leftElbowAngle, ctx.rightElbowAngle);
    }

    _debugData['leftLeadCount'] = leftLeadCount;
    _debugData['rightLeadCount'] = rightLeadCount;
    _debugData['currentLeadArm'] = currentLeadArm ?? 'None';
  }

  void detectLeadArm(double leftElbow, double rightElbow) {
    if (leftElbow > 100.0 && rightElbow <= 110.0) {
      currentLeadArm = 'left';
      leftLeadCount++;
      _evaluateSymmetry();
    } else if (rightElbow > 100.0 && leftElbow <= 110.0) {
      currentLeadArm = 'right';
      rightLeadCount++;
      _evaluateSymmetry();
    }
  }

  void _evaluateSymmetry() {
    if (lastLeadArm != null && currentLeadArm == lastLeadArm) {
      _faults.add(FaultRecord(
        phase: 'pushing_up',
        type: 'alternating',
        message: 'Không đổi tay dẫn khi đẩy lên',
        affectsForm: false,
        voiceMessage: 'Bạn nên đổi tay dẫn đẩy lên để cân bằng lực cơ.',
        priority: PlankFaultVoicePriority.armExtension,
      ));
    }
  }

  @override
  void reset() {
    if (currentLeadArm != null) {
      lastLeadArm = currentLeadArm;
    }
    currentLeadArm = null;
    _faults.clear();
  }
}
