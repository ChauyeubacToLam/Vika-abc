import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import '../low_lunge.dart';

class LowLungeContext {
  final LowLungeState state;
  final int frameTimestampMs;
  final double scaleFactor;
  final ResultIssues resultIssues;
  final CameraFacing cameraFacing;
  final BodySide frontSide;
  final double lungeDirection;
  final double trunkClockAngle;
  final double hipVelocity;

  final PoseLandmark? frontShoulder;
  final PoseLandmark? frontHip;
  final PoseLandmark? frontKnee;
  final PoseLandmark? frontAnkle;
  final PoseLandmark? backHip;
  final PoseLandmark? backKnee;
  final PoseLandmark? backAnkle;
  final PoseLandmark? ear;

  final double? baselineCervicalAngle;
  final double? frontAnkleBaselineX;

  LowLungeContext({
    required this.state,
    required this.frameTimestampMs,
    required this.scaleFactor,
    required this.resultIssues,
    required this.cameraFacing,
    required this.frontSide,
    required this.lungeDirection,
    required this.trunkClockAngle,
    required this.hipVelocity,
    this.frontShoulder,
    this.frontHip,
    this.frontKnee,
    this.frontAnkle,
    this.backHip,
    this.backKnee,
    this.backAnkle,
    this.ear,
    this.baselineCervicalAngle,
    this.frontAnkleBaselineX,
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

abstract class LowLungeMetricBase {
  String get name;
  int faultsCount = 0;

  void update(LowLungeContext ctx);

  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;

  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(
    LowLungeState from,
    LowLungeState to,
    int timestampMs,
  ) {}
}
