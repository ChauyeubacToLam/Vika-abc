import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/debug/debug_types.dart';
import 'package:vika/exercise/exercise_base.dart';
import '../prayer_pose.dart';

class PrayerPoseContext {
  final PrayerPoseState state;
  final int frameTimestampMs;
  final double scaleFactor;
  final ResultIssues resultIssues;
  final CameraFacing cameraFacing;

  final double trunkClockAngle;
  final double hipVelocity;
  final double earShoulderDistanceRatio;

  final PoseLandmark? ear;
  final PoseLandmark? shoulder;
  final PoseLandmark? hip;
  final PoseLandmark? ankle;

  final double? trunkBaseline;
  final double? cervicalBaseline;
  final double? postureBaseline;
  final double? shoulderEaseBaseline;

  PrayerPoseContext({
    required this.state,
    required this.frameTimestampMs,
    required this.scaleFactor,
    required this.resultIssues,
    required this.cameraFacing,
    required this.trunkClockAngle,
    required this.hipVelocity,
    required this.earShoulderDistanceRatio,
    this.ear,
    this.shoulder,
    this.hip,
    this.ankle,
    this.trunkBaseline,
    this.cervicalBaseline,
    this.postureBaseline,
    this.shoulderEaseBaseline,
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

abstract class PrayerPoseMetricBase implements DebugMetricSource {
  @override
  String get name;
  int faultsCount = 0;

  void update(PrayerPoseContext ctx);

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
    PrayerPoseState from,
    PrayerPoseState to,
    int timestampMs,
  ) {}
}
