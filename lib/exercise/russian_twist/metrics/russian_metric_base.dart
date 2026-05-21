import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../exercise_base.dart';
import '../russian_twist.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';


class RussianRepContext {
  final double midWristX;
  final double midKneeX;
  final double shoulderWidth;
  final double hipWidth;
  final double shoulderToHipY;
  final double leftHipX;
  final double rightHipX;
  
  final RussianTwistState state;
  final TwistDirection direction;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  RussianRepContext({
    required this.midWristX,
    required this.midKneeX,
    required this.shoulderWidth,
    required this.hipWidth,
    required this.shoulderToHipY,
    required this.leftHipX,
    required this.rightHipX,
    required this.state,
    required this.direction,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

abstract class RussianMetricBase {
  int _faultsCount = 0;
  final List<FaultRecord> _faults = [];
  Map<String, dynamic> debugData = {};

  int get faultsCount => _faultsCount;
  List<FaultRecord> get faults => List.unmodifiable(_faults);

  void update(RussianRepContext ctx);

  void onStateTransition(RussianTwistState oldState, RussianTwistState newState, TwistDirection dir, int timestampMs) {}

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
