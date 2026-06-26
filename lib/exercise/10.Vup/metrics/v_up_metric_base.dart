import '../../exercise_base.dart';
import '../../fault_record.dart';
import '../../../debug/debug_types.dart';
export '../../../debug/debug_types.dart';
export '../../fault_record.dart';

enum VUpState { lying, rising, v_position, lowering }

class VUpConfig {
  static const int MAX_REP = 12;
  static const int TIMEOUT_MS = 90000;

  // Start position must be a real flat, extended V-up baseline.
  static const double START_BODY_MIN = 155.0;
  static const double START_KNEE_MIN = 145.0;
  static const double START_TRUNK_HORIZ_MAX = 24.0;
  static const double START_LEG_HORIZ_MAX = 24.0;
  static const double START_Y_SPREAD_MAX = 0.42;
  static const double START_WRIST_ANKLE_DIST_MIN = 1.55;

  // Rep gating.
  static const int REP_READY_FRAMES = 3;
  static const double RISING_ANGLE = 160.0;
  static const double RISING_MIN_LIFT = 0.08;
  static const double V_POSITION_THRESHOLD = 130.0;
  static const double ROM_TARGET_ANGLE = 112.0;
  static const double TOP_TRUNK_HORIZ_MIN = 14.0;
  static const double TOP_LEG_HORIZ_MIN = 14.0;
  static const double TOP_MIN_LIFT = 0.12;
  static const double TOP_WRIST_ANKLE_DIST_MAX = 1.25;
  static const double TOP_WRIST_ANKLE_CLOSURE_MIN = 0.55;
  static const double TOP_ARM_REACH_DIST_MAX = 1.85;
  static const double TOP_ARM_REACH_CLOSURE_MIN = 0.25;
  static const double ACTIVE_KNEE_MIN = 138.0;
  static const double LOWERING_THRESHOLD_DIFF = 5.0;
  static const double LYING_ANGLE = 152.0;
}

class VUpRepContext {
  final double shoulderHipAnkleAngle;
  final double hipKneeAnkleAngle;
  final double wristAnkleDistance;
  final double trunkHorizontalAngle;
  final double legHorizontalAngle;

  final double shoulderY;
  final double ankleY;
  final double hipY;
  final double? scaleFactor;
  final double shoulderLiftFromBaseline;
  final double ankleLiftFromBaseline;
  final double wristAnkleClosureFromBaseline;

  final bool isHorizontal;
  final bool bothArmsLifted;
  final bool bothLegsLifted;
  final bool isStrictLying;
  final bool isStrictVPosition;

  final VUpState state;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  VUpRepContext({
    required this.shoulderHipAnkleAngle,
    required this.hipKneeAnkleAngle,
    required this.wristAnkleDistance,
    required this.trunkHorizontalAngle,
    required this.legHorizontalAngle,
    required this.shoulderY,
    required this.ankleY,
    required this.hipY,
    required this.scaleFactor,
    required this.shoulderLiftFromBaseline,
    required this.ankleLiftFromBaseline,
    required this.wristAnkleClosureFromBaseline,
    required this.isHorizontal,
    required this.bothArmsLifted,
    required this.bothLegsLifted,
    required this.isStrictLying,
    required this.isStrictVPosition,
    required this.state,
    required this.frameTimestampMs,
    required this.resultIssues,
  });

  VUpRepContext copyWith({VUpState? state}) {
    return VUpRepContext(
      shoulderHipAnkleAngle: shoulderHipAnkleAngle,
      hipKneeAnkleAngle: hipKneeAnkleAngle,
      wristAnkleDistance: wristAnkleDistance,
      trunkHorizontalAngle: trunkHorizontalAngle,
      legHorizontalAngle: legHorizontalAngle,
      shoulderY: shoulderY,
      ankleY: ankleY,
      hipY: hipY,
      scaleFactor: scaleFactor,
      shoulderLiftFromBaseline: shoulderLiftFromBaseline,
      ankleLiftFromBaseline: ankleLiftFromBaseline,
      wristAnkleClosureFromBaseline: wristAnkleClosureFromBaseline,
      isHorizontal: isHorizontal,
      bothArmsLifted: bothArmsLifted,
      bothLegsLifted: bothLegsLifted,
      isStrictLying: isStrictLying,
      isStrictVPosition: isStrictVPosition,
      state: state ?? this.state,
      frameTimestampMs: frameTimestampMs,
      resultIssues: resultIssues,
    );
  }
}

class VUpFaultPriority {
  static const int syncElevation = 0;
  static const int jerking = 1;
  static const int rom = 2;
  static const int bentKnee = 3;
  static const int tempo = 4;
}

abstract class VUpMetricBase implements DebugMetricSource {
  @override
  String get name;
  int faultsCount = 0;
  void update(VUpRepContext ctx);
  List<FaultRecord> get faults;
  @override
  Map<String, dynamic> get debugData;
  @override
  double? get value => null;
  @override
  ThresholdBand? get threshold => null;
  @override
  MetricStatus get status {
    if (faults.any((fault) => fault.affectsForm)) {
      return MetricStatus.fault;
    }
    if (faults.isNotEmpty) return MetricStatus.near;
    return MetricStatus.pass;
  }

  @override
  String? get nameVi => null;
  @override
  bool get devOnly => false;
  void reset();
  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(VUpState from, VUpState to, int timestampMs) {}
}
