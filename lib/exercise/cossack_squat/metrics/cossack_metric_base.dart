import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../exercise_base.dart';
import '../cossack_squat.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';


class CossackRepContext {
  final WorkingLeg workingLeg;
  final double workingHeelDistance;
  final double workingKneeX;
  final double workingAnkleX;
  final double workingFootIndexX;
  
  final double workingKneeAngle;
  final double straightKneeAngle;
  final double torsoAngle;
  
  final CossackState state;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  CossackRepContext({
    required this.workingLeg,
    required this.workingHeelDistance,
    required this.workingKneeX,
    required this.workingAnkleX,
    required this.workingFootIndexX,
    required this.workingKneeAngle,
    required this.straightKneeAngle,
    required this.torsoAngle,
    required this.state,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

abstract class CossackMetricBase {
  int _faultsCount = 0;
  final List<FaultRecord> _faults = [];
  Map<String, dynamic> debugData = {};

  int get faultsCount => _faultsCount;
  List<FaultRecord> get faults => List.unmodifiable(_faults);

  void update(CossackRepContext ctx);

  void onStateTransition(CossackState oldState, CossackState newState, int timestampMs) {}

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
