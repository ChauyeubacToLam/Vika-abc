import '../../exercise_base.dart';
import '../../fault_record.dart';
import '../../../debug/debug_types.dart';
export '../../../debug/debug_types.dart';
export '../../fault_record.dart';

class LegRaiseConfig {
  static const int MAX_REP = 12; // Beginner/Conservative
  static const int TIMEOUT_MS = 90000; // 90s

  // Start Position Limits
  static const double START_HIP_FLEXION_MIN = 155.0; // Gần 180 độ
  static const double START_KNEE_STRAIGHT_MIN = 140.0; // Beginner-friendly

  // State Transition Thresholds
  static const double RAISING_ANGLE = 160.0;
  static const double TOP_ANGLE = 135.0;
  static const double LOWERING_ANGLE = 145.0;
  static const double LYING_ANGLE = 150.0;

  // Tempo Thresholds (Unified: fault if < 2.0s, target if >= 2.0s)
  static const double TEMPO_FAULT_THRESHOLD = 1.2;
  static const double TEMPO_TARGET_THRESHOLD = 1.5;

  // Trunk Angle Limit
  static const double MAX_TRUNK_ANGLE = 55.0;

  // Arm position: elbows straight, wrists kept beside the hips.
  static const double ARM_ELBOW_STRAIGHT_MIN = 135.0;
  static const double ARM_WRIST_HIP_MAX_RATIO = 0.95;
}

enum LegRaiseState { lying, raising, top, lowering }

class LegRaiseRepContext {
  final double hipFlexionAngle; // Góc Vai-Hông-Đầu gối (ROM)
  final double kneeStraightnessAngle; // Góc Hông-Đầu gối-Mắt cá (Độ thẳng chân)
  final double
      trunkHorizontalAngle; // Góc ngang của thân người (chống gian lận bằng cách ngồi dậy)

  final double hipY; // Tọa độ Y của hông để đo độ võng lưng (Pelvic tilt)
  final double ankleY; // Dùng để đo vận tốc khi ở pha TOP
  final double scaleFactor; // Khoảng cách Shoulder-Hip (chuẩn hóa kích thước)

  final bool armsVisible;
  final double? armStraightnessAngle;
  final double? wristHipDistanceRatio;

  final LegRaiseState state;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  LegRaiseRepContext({
    required this.hipFlexionAngle,
    required this.kneeStraightnessAngle,
    required this.trunkHorizontalAngle,
    required this.hipY,
    required this.ankleY,
    required this.scaleFactor,
    required this.armsVisible,
    required this.armStraightnessAngle,
    required this.wristHipDistanceRatio,
    required this.state,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

class LegRaiseFaultPriority {
  static const int pelvicInstability = 0; // Võng lưng/Nhấc hông (Critical)
  static const int tempo = 1; // Thả rơi chân (Critical)
  static const int bentKnee = 2; // Gập gối (Medium)
  static const int rom = 3; // Lên chưa đủ cao (Low)
}

abstract class LegRaiseMetricBase {
  String get name;
  int faultsCount = 0;
  void update(LegRaiseRepContext ctx);
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
      LegRaiseState from, LegRaiseState to, int timestampMs) {}
}
