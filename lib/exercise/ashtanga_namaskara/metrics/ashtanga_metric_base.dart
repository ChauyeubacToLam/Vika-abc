import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/debug/debug_types.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/fault_record.dart';
import '../ashtanga_namaskara.dart';
export 'package:vika/exercise/fault_record.dart';

class AshtangaContext {
  final AshtangaState state;
  final AshtangaMode mode;
  final int frameTimestampMs;
  final double scaleFactor;
  final ResultIssues resultIssues;
  final CameraFacing cameraFacing;

  final double hipPositionRatio;
  final double cervicalAngle;
  final bool kneesGrounded;
  final bool chestLow;
  final double shoulderHipDelta;
  final double kneeAnkleDelta;

  final PoseLandmark? shoulder;
  final PoseLandmark? hip;
  final PoseLandmark? knee;
  final PoseLandmark? ankle;
  final PoseLandmark? ear;

  final double? cervicalBaseline;

  AshtangaContext({
    required this.state,
    required this.mode,
    required this.frameTimestampMs,
    required this.scaleFactor,
    required this.resultIssues,
    required this.cameraFacing,
    required this.hipPositionRatio,
    required this.cervicalAngle,
    required this.kneesGrounded,
    required this.chestLow,
    required this.shoulderHipDelta,
    required this.kneeAnkleDelta,
    this.shoulder,
    this.hip,
    this.knee,
    this.ankle,
    this.ear,
    this.cervicalBaseline,
  });
}

abstract class AshtangaMetricBase {
  String get name;
  int faultsCount = 0;

  void update(AshtangaContext ctx);

  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  double? get value => null;
  ThresholdBand? get threshold => null;
  MetricStatus get status => faults.any((fault) => fault.affectsForm)
      ? MetricStatus.fault
      : MetricStatus.pass;
  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(
    AshtangaState from,
    AshtangaState to,
    int timestampMs,
  ) {}
}
