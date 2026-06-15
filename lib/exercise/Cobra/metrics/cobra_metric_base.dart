import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import '../cobra.dart';

class RepContext {
  // --- Core state ---
  final double trunkClockAngle;
  final double trunkDeviation;
  final bool isStanding;
  final CobraState state;
  final int frameTimestampMs;
  final double scaleFactor;
  final ResultIssues resultIssues;
  final CameraFacing cameraFacing;

  // --- Landmarks (camera-side, nullable for safety) ---
  final PoseLandmark? shoulder;
  final PoseLandmark? hip;
  final PoseLandmark? elbow;
  final PoseLandmark? wrist;
  final PoseLandmark? ear;
  final PoseLandmark? knee;

  // --- Calibration baselines (captured during prone setup) ---
  final double? baselineHipY;
  final double? baselineTrunkLength;
  final double? baselineCervicalAngle;

  RepContext({
    required this.trunkClockAngle,
    required this.trunkDeviation,
    required this.isStanding,
    required this.state,
    required this.frameTimestampMs,
    required this.scaleFactor,
    required this.resultIssues,
    required this.cameraFacing,
    this.shoulder,
    this.hip,
    this.elbow,
    this.wrist,
    this.ear,
    this.knee,
    this.baselineHipY,
    this.baselineTrunkLength,
    this.baselineCervicalAngle,
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

abstract class CobraMetricBase {
  String get name;
  int faultsCount = 0;

  void update(RepContext ctx);

  List<FaultRecord> get faults;
  bool get isFaultingNow => false;
  Map<String, dynamic> get debugData;

  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(
    CobraState from,
    CobraState to,
    int timestampMs,
  ) {}
}
