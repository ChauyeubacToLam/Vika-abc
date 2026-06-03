// ignore_for_file: constant_identifier_names

import '../../exercise_base.dart';
import '../../fault_record.dart';
import '../../../debug/debug_types.dart';
export '../../../debug/debug_types.dart';
export '../../fault_record.dart';

enum PlankState { forearm_plank, pushing_up, high_plank, lowering }

class PlankConfig {
  static const int MAX_REP = 12; // Mức Intermediate
  static const int MAX_DURATION_MS = 90000; // 90 giây timeout
  static const int HOLD_DURATION_MS = 3000;
  static const double HOLD_DURATION_SECONDS = HOLD_DURATION_MS / 1000;

  // Góc cơ thể (Shoulder-Hip-Ankle)
  static const double BODY_ALIGNMENT_START_MIN = 170.0;
  static const double BODY_ALIGNMENT_SAG_THRESHOLD = 160.0; // Sụt hông

  // Góc gối (Hip-Knee-Ankle)
  static const double KNEE_EXTENSION_MIN =
      150.0; // Yêu cầu thẳng chân, dưới mức này coi như co gối

  // Góc tay (Shoulder-Elbow-Wrist)
  static const double ELBOW_FOREARM_MAX = 110.0; // ~90 độ
  static const double ELBOW_PUSHING_THRESHOLD = 100.0;
  static const double ELBOW_HIGH_PLANK_MIN = 160.0; // ~180 độ
  static const double ELBOW_LOWERING_THRESHOLD = 150.0;

  // Cố định hông (pixel, sẽ chuẩn hóa theo chiều dài lưng)
  static const double HIP_Y_ROTATION_TOLERANCE = 0.15; // 15% chiều dài lưng
}

class PlankFaultVoicePriority {
  static const int trunkSagging = 0; // Quan trọng nhất
  static const int hipRotation = 1;
  static const int armExtension = 2;
}

class PlankRepContext {
  final double bodyAngle;
  final double kneeAngle;
  final double leftElbowAngle;
  final double rightElbowAngle;
  final double hipY;
  final double shoulderY;
  final double? scaleFactor; // Chiều dài vai-hông để chuẩn hóa khoảng cách
  final PlankState currentState;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  PlankRepContext({
    required this.bodyAngle,
    required this.kneeAngle,
    required this.leftElbowAngle,
    required this.rightElbowAngle,
    required this.hipY,
    required this.shoulderY,
    required this.scaleFactor,
    required this.currentState,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

abstract class PlankMetricBase implements DebugMetricSource {
  @override
  String get name;
  int faultsCount = 0;
  List<FaultRecord> get faults;
  @override
  Map<String, dynamic> get debugData;
  @override
  double? get value => null;
  @override
  ThresholdBand? get threshold => null;
  @override
  MetricStatus get status => MetricStatus.pass;
  @override
  String? get nameVi => null;
  @override
  bool get devOnly => false;

  void update(PlankRepContext ctx);
  void reset();
  void onStateTransition(PlankState from, PlankState to, int timestampMs) {}

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }
}
