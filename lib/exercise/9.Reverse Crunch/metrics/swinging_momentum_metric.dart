import 'reverse_crunch_metric_base.dart';

class SwingingMomentumMetric extends ReverseCrunchMetricBase {
  @override
  String get name => 'SwingingMomentum';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  bool _earlyKickDetected = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.state == ReverseCrunchState.lying) {
      ctx.resultIssues.feedback['KneeLock'] = 'Sẵn sàng co gối';
      return;
    }

    final earlyKick = ctx.state == ReverseCrunchState.curling &&
        !ctx.isContractionPosition &&
        ctx.kneeAngle >= ReverseCrunchConfig.EARLY_KICK_KNEE_EXTENSION_MIN &&
        ctx.hipLiftNormalized < ReverseCrunchConfig.HIP_LIFT_MIN_NORMALIZED;

    _debugData['kneeAngle'] = ctx.kneeAngle.toStringAsFixed(1);
    _debugData['hipLift'] = ctx.hipLiftNormalized.toStringAsFixed(2);
    _debugData['earlyKick'] = earlyKick;

    if (earlyKick) {
      _earlyKickDetected = true;
      ctx.resultIssues.feedback['KneeLock'] = 'Đừng đạp chân sớm';
    } else {
      ctx.resultIssues.feedback['KneeLock'] = 'Nhịp chân tốt';
    }
  }

  @override
  void evaluateRepEnd(RepContext ctx) {
    if (!_earlyKickDetected) return;

    _faults.add(FaultRecord(
      phase: 'CURLING',
      type: 'Swinging',
      message: 'Duỗi chân quá sớm để lấy đà',
      affectsForm: true,
      priority: CrunchVoicePriority.momentum,
      voiceMessage: 'Co gối về ngực trước, rồi mới duỗi chân lên ở đỉnh.',
    ));
    ctx.resultIssues.addInstruction(
      'lying',
      'KneeLock',
      'Rep trước bạn duỗi chân hơi sớm. Hãy co gối về ngực trước rồi mới leg thrust.',
    );
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _earlyKickDetected = false;
  }
}
