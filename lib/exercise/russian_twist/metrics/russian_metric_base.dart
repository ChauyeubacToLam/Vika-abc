// ignore_for_file: annotate_overrides

import '../../exercise_base.dart';
import '../russian_twist.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

/// Per-frame context handed to every Russian Twist metric.
///
/// All lateral signals are expressed relative to the body's midline and
/// normalized by shoulder width so that values are body-size and
/// camera-distance independent. A positive `lateralOffset` means the point
/// is on the body's left side, negative means the body's right side.
class RussianRepContext {
  // Raw landmark coordinates (front-view, bilateral).
  final double midShoulderX;
  final double midShoulderY;
  final double midHipX;
  final double midHipY;
  final double midKneeX;
  final double midKneeY;

  final double wristX;
  final double wristY;

  final double leftShoulderX;
  final double leftShoulderY;
  final double rightShoulderX;
  final double rightShoulderY;

  final double leftKneeX;
  final double leftKneeY;
  final double rightKneeX;
  final double rightKneeY;

  final double leftHipX;
  final double leftHipY;
  final double rightHipX;
  final double rightHipY;

  // Normalized lateral signals.
  /// Signed wrist lateral offset: (wrist.x - midShoulder.x) / shoulderWidth.
  /// Positive = wrist to body-left of midline, negative = to body-right.
  final double wristLateralOffset;

  /// Signed shoulder-rotation offset: how far the shoulder midpoint has
  /// shifted laterally from the hip midpoint, normalized by shoulder width.
  /// Reflects torso/chest rotation toward one side.
  final double shoulderRotationOffset;

  /// Signed knee drift from setup position, normalized by shoulder width.
  final double kneeDriftRatio;

  /// Angle of the trunk (shoulder midpoint -> hip midpoint) measured from the
  /// horizontal axis, in degrees. Used to detect upright vs leaned-back torso.
  final double trunkHorizontalAngle;

  /// Normalized shoulder width (the scale factor for this frame).
  final double shoulderWidth;

  final RussianTwistState state;
  final TwistDirection direction;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  RussianRepContext({
    required this.midShoulderX,
    required this.midShoulderY,
    required this.midHipX,
    required this.midHipY,
    required this.midKneeX,
    required this.midKneeY,
    required this.wristX,
    required this.wristY,
    required this.leftShoulderX,
    required this.leftShoulderY,
    required this.rightShoulderX,
    required this.rightShoulderY,
    required this.leftKneeX,
    required this.leftKneeY,
    required this.rightKneeX,
    required this.rightKneeY,
    required this.leftHipX,
    required this.leftHipY,
    required this.rightHipX,
    required this.rightHipY,
    required this.wristLateralOffset,
    required this.shoulderRotationOffset,
    required this.kneeDriftRatio,
    required this.trunkHorizontalAngle,
    required this.shoulderWidth,
    required this.state,
    required this.direction,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

abstract class RussianMetricBase with FaultMetricDebugSource {
  int _faultsCount = 0;
  final List<FaultRecord> _faults = [];
  Map<String, dynamic> debugData = {};

  @override
  String get name => runtimeType.toString();
  int get faultsCount => _faultsCount;
  List<FaultRecord> get faults => List.unmodifiable(_faults);

  void update(RussianRepContext ctx);

  void onStateTransition(RussianTwistState oldState, RussianTwistState newState,
      TwistDirection dir, int timestampMs) {}

  void addFault(FaultRecord fault) {
    if (!_faults.any((f) => f.type == fault.type)) {
      _faults.add(fault);
    }
  }

  void reset() {
    _faults.clear();
    debugData.clear();
  }

  void resetAndCountFault() {
    if (_faults.isNotEmpty) {
      _faultsCount++;
    }
    reset();
  }
}
