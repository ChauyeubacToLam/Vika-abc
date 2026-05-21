import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../exercise_base.dart';
import 'package:vika/exercise/side_tracked_exercise_mixin.dart';
import '../standing_knee_to_elbow.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';


class StandingKteRepContext {
  final TrackedSide standingLegSide;
  final PoseLandmark standingKnee;
  final PoseLandmark standingAnkle;
  final PoseLandmark liftingKnee;
  final PoseLandmark standingHip;
  final PoseLandmark liftingHip;
  final PoseLandmark liftingShoulder; // Shoulder on the side of the lifting leg
  final PoseLandmark opposingElbow;   // Elbow moving towards the lifting knee
  
  final double hipWidth;
  final double torsoLength;
  final double distanceD; // Distance between opposingElbow and liftingKnee
  
  final KteState state;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  StandingKteRepContext({
    required this.standingLegSide,
    required this.standingKnee,
    required this.standingAnkle,
    required this.liftingKnee,
    required this.standingHip,
    required this.liftingHip,
    required this.liftingShoulder,
    required this.opposingElbow,
    required this.hipWidth,
    required this.torsoLength,
    required this.distanceD,
    required this.state,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

abstract class StandingKteMetricBase {
  int _faultsCount = 0;
  final List<FaultRecord> _faults = [];
  Map<String, dynamic> debugData = {};

  int get faultsCount => _faultsCount;
  List<FaultRecord> get faults => List.unmodifiable(_faults);

  void update(StandingKteRepContext ctx);

  void onStateTransition(KteState oldState, KteState newState, int timestampMs) {}

  void addFault(FaultRecord fault) {
    if (!_faults.any((f) => f.type == fault.type)) {
      _faults.add(fault);
    }
  }

  void resetAndCountFault() {
    if (_faults.isNotEmpty) {
      _faultsCount++;
    }
    _faults.clear();
    debugData.clear();
  }
}
