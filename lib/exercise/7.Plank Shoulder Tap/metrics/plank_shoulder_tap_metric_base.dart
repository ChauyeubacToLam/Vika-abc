// ignore_for_file: constant_identifier_names
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum PlankTapState { base, lifting, tap, returning }

class PlankTapConfig {
  static const int MAX_REP = 20;
  static const int MAX_DURATION_MS = 90000;

  // Body line: shoulder-hip-ankle should stay nearly straight.
  static const List<double> TRUNK_STRAIGHT_RANGE = [170.0, 180.0];

  // State machine thresholds normalized by shoulder-hip distance.
  static const double LIFT_START_THRESHOLD = 0.85;
  static const double TAP_DISTANCE_THRESHOLD = 0.70;
  static const double WRIST_LIFT_START_THRESHOLD = 0.10;
  static const double WRIST_RETURN_THRESHOLD = 0.04;

  static const double HIP_ROTATION_TOLERANCE = 0.15;
  static const double HIP_WIDTH_DRIFT_TOLERANCE = 0.10;
  static const double TRUNK_SAG_THRESHOLD = 160.0;
  static const double MIN_TAP_TIME = 0.5;
}

class PlankTapVoicePriority {
  static const int hipRotation = 0;
  static const int trunkAlignment = 1;
  static const int clearTap = 2;
  static const int tempo = 3;
}

class RepContext {
  final PlankTapState state;
  final int frameTimestamp;
  final double scaleFactor;
  final double trunkAngle;
  final double hipY;
  final double activeWristShoulderDistNorm;
  final double wristLiftNorm;
  final double? hipWidthXNorm;
  final ResultIssues resultIssues;

  RepContext({
    required this.state,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.trunkAngle,
    required this.hipY,
    required this.activeWristShoulderDistNorm,
    required this.wristLiftNorm,
    this.hipWidthXNorm,
    required this.resultIssues,
  });
}

abstract class PlankTapMetricBase {
  String get name;
  int faultsCount = 0;

  void update(RepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(
      PlankTapState from, PlankTapState to, int timestampMs) {}
  void evaluateRepEnd(RepContext ctx) {}
}
