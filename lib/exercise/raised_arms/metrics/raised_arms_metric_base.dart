import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/debug/debug_types.dart';
import 'package:vika/exercise/exercise_base.dart';
import '../raised_arms.dart';

class RaisedArmsContext {
  final RaisedArmsState state;
  final int frameTimestampMs;
  final double scaleFactor;
  final ResultIssues resultIssues;
  final CameraFacing cameraFacing;

  final double trunkClockAngle;
  final double backLean;
  final double hipVelocity;
  final double cervicalAngle;
  final double armVerticalAngle;
  final double elbowAngle;
  final bool wristVisible;

  final PoseLandmark? shoulder;
  final PoseLandmark? hip;
  final PoseLandmark? elbow;
  final PoseLandmark? wrist;
  final PoseLandmark? ear;

  final double? trunkBaseline;
  final double? cervicalBaseline;

  RaisedArmsContext({
    required this.state,
    required this.frameTimestampMs,
    required this.scaleFactor,
    required this.resultIssues,
    required this.cameraFacing,
    required this.trunkClockAngle,
    required this.backLean,
    required this.hipVelocity,
    required this.cervicalAngle,
    required this.armVerticalAngle,
    required this.elbowAngle,
    required this.wristVisible,
    this.shoulder,
    this.hip,
    this.elbow,
    this.wrist,
    this.ear,
    this.trunkBaseline,
    this.cervicalBaseline,
  });
}

class FaultRecord {
  final String phase;
  final String type;
  final String message;
  final bool affectsForm;

  FaultRecord({
    required this.phase,
    required this.type,
    required this.message,
    required this.affectsForm,
  });
}

abstract class RaisedArmsMetricBase implements DebugMetricSource {
  @override
  String get name;
  int faultsCount = 0;

  void update(RaisedArmsContext ctx);

  List<FaultRecord> get faults;
  @override
  Map<String, dynamic> get debugData;
  @override
  double? get value => null;
  @override
  ThresholdBand? get threshold => null;
  @override
  MetricStatus get status => faults.any((fault) => fault.affectsForm)
      ? MetricStatus.fault
      : MetricStatus.pass;
  @override
  String? get nameVi => null;
  @override
  bool get devOnly => false;

  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(
    RaisedArmsState from,
    RaisedArmsState to,
    int timestampMs,
  ) {}
}
