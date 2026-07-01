import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../exercise_base.dart';
import '../walking_lunge.dart';
import '../../fault_record.dart';
import '../../../debug/debug_types.dart';
export '../../../debug/debug_types.dart';
export '../../fault_record.dart';

class WalkingRepContext {
  final double thighLength;
  final PoseLandmark frontKnee;
  final PoseLandmark frontAnkle;
  final PoseLandmark frontFoot;
  final PoseLandmark rearKnee;
  final PoseLandmark rearAnkle;
  final PoseLandmark hip;
  final PoseLandmark shoulder;

  final double frontKneeAngle;
  final double rearKneeAngle;
  final double torsoAngle;
  final double stepLengthX;
  double get normalizedStepLength =>
      thighLength > 1e-6 ? stepLengthX / thighLength : 0.0;

  final WalkingState state;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  WalkingRepContext({
    required this.thighLength,
    required this.frontKnee,
    required this.frontAnkle,
    required this.frontFoot,
    required this.rearKnee,
    required this.rearAnkle,
    required this.hip,
    required this.shoulder,
    required this.frontKneeAngle,
    required this.rearKneeAngle,
    required this.torsoAngle,
    required this.stepLengthX,
    required this.state,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

class WalkingFaultPriority {
  static const int hold = 1;
  static const int kneeControl = 2;
  static const int rearDepth = 2;
  static const int torsoLean = 3;
  static const int stepConsistency = 3;
}

abstract class WalkingMetricBase implements DebugMetricSource {
  int _faultsCount = 0;
  final List<FaultRecord> _faults = [];
  @override
  Map<String, dynamic> debugData = {};

  int get faultsCount => _faultsCount;
  List<FaultRecord> get faults => List.unmodifiable(_faults);
  @override
  String get name => runtimeType.toString();
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

  void update(WalkingRepContext ctx);

  void onStateTransition(
      WalkingState oldState, WalkingState newState, int timestampMs) {}

  void addFault(FaultRecord fault) {
    if (!_faults.any((f) => f.type == fault.type)) {
      _faults.add(fault);
    }
  }

  void reset() {
    _faults.clear();
    debugData.clear();
  }

  void resetAndCountFault() {
    if (_faults.isNotEmpty) {
      _faultsCount++;
    }
    reset();
  }
}
