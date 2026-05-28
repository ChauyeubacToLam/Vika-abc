import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../exercise_base.dart';
import '../tricep_dip.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';


class TricepRepContext {
  final double elbowAngle;
  final PoseLandmark shoulder;
  final PoseLandmark elbow;
  final PoseLandmark wrist;
  final PoseLandmark hip;
  final PoseLandmark? ear;
  final double forearmLength;
  
  final TricepDipState state;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  TricepRepContext({
    required this.elbowAngle,
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.hip,
    this.ear,
    required this.forearmLength,
    required this.state,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

abstract class TricepMetricBase {
  int _faultsCount = 0;
  final List<FaultRecord> _faults = [];
  Map<String, dynamic> debugData = {};

  int get faultsCount => _faultsCount;
  List<FaultRecord> get faults => List.unmodifiable(_faults);

  void update(TricepRepContext ctx);

  void onStateTransition(TricepDipState oldState, TricepDipState newState, int timestampMs) {}

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
