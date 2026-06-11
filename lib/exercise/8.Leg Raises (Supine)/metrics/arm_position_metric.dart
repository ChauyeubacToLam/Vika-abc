import 'leg_raise_metric_base.dart';
import '../../../utils/debouncer.dart';

class ArmPositionMetric extends LegRaiseMetricBase {
  @override
  String get name => 'ArmPosition';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 3);
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LegRaiseRepContext ctx) {
    if (ctx.state == LegRaiseState.lying) return;

    final armStraightness = ctx.armStraightnessAngle;
    final wristHipDistance = ctx.wristHipDistanceRatio;
    final armsVisible =
        ctx.armsVisible && armStraightness != null && wristHipDistance != null;

    _debugData['armsVisible'] = armsVisible;
    _debugData['armStraightness'] =
        armStraightness?.toStringAsFixed(1) ?? 'N/A';
    _debugData['wristHipRatio'] = wristHipDistance?.toStringAsFixed(2) ?? 'N/A';

    final armsBent =
        armsVisible && armStraightness < LegRaiseConfig.ARM_ELBOW_STRAIGHT_MIN;
    final armsAway = armsVisible &&
        wristHipDistance > LegRaiseConfig.ARM_WRIST_HIP_MAX_RATIO;

    if (_faultDebouncer.update(!armsVisible || armsBent || armsAway)) {
      final message = !armsVisible
          ? 'Không thấy rõ tay'
          : armsBent
              ? 'Khuỷu tay đang gập'
              : 'Tay rời xa hông';
      ctx.resultIssues.feedback['Arms'] = 'Duỗi thẳng hai tay, khép sát hông.';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          'lying',
          'Arms',
          'Duỗi thẳng hai tay và khép sát bên hông trong suốt rep.',
        );
        _instructionSet = true;
      }
      _logFault(ctx.state.name, message);
    } else {
      ctx.resultIssues.feedback['Arms'] = 'Tay sát hông tốt';
    }
  }

  void _logFault(String phase, String message) {
    if (_faults.any((f) => f.type == 'ArmPosition')) return;
    _faults.add(FaultRecord(
      phase: phase,
      type: 'ArmPosition',
      message: message,
      voiceMessage: 'Duỗi thẳng tay và khép sát hông',
      affectsForm: true,
      priority: LegRaiseFaultPriority.bentKnee,
    ));
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _faultDebouncer.reset();
    _instructionSet = false;
  }
}
