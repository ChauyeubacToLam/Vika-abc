import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum VUpState { lying, rising, v_position, lowering }

class VUpConfig {
  static const int MAX_REP = 12; // Cường độ cao, dừng ở 12
  static const int TIMEOUT_MS = 90000; // 90s
  
  // Start Position Limits
  static const double START_BODY_MIN = 165.0; // Duỗi thẳng người

  // State Transition Thresholds
  static const double RISING_ANGLE = 160.0;
  static const double V_POSITION_THRESHOLD = 80.0; // Ngưỡng để nhận diện pha đỉnh (state machine)
  static const double ROM_TARGET_ANGLE = 60.0; // Góc mục tiêu cho gập sâu hoàn hảo
  static const double LOWERING_THRESHOLD_DIFF = 5.0; // Góc mở ra 5 độ so với đỉnh
  static const double LYING_ANGLE = 160.0;
}

class VUpRepContext {
  final double shoulderHipAnkleAngle; // Góc chữ V
  final double hipKneeAnkleAngle;     // Độ thẳng gối
  final double wristAnkleDistance;    // Khoảng cách tay - chân (chuẩn hóa)
  
  final double shoulderY;
  final double ankleY;
  final double hipY;
  final double? scaleFactor; // Khoảng cách Shoulder-Hip (chuẩn hóa kích thước)
  
  final bool isHorizontal;
  final bool bothArmsLifted;
  final bool bothLegsLifted;
  
  final VUpState state;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  VUpRepContext({
    required this.shoulderHipAnkleAngle,
    required this.hipKneeAnkleAngle,
    required this.wristAnkleDistance,
    required this.shoulderY,
    required this.ankleY,
    required this.hipY,
    required this.scaleFactor,
    required this.isHorizontal,
    required this.bothArmsLifted,
    required this.bothLegsLifted,
    required this.state,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

class VUpFaultPriority {
  static const int syncElevation = 0; // Mất đồng bộ (Critical)
  static const int jerking = 1;       // Giật cục (Critical)
  static const int rom = 2;           // Góc hông rộng (High)
  static const int bentKnee = 3;      // Gập gối (Medium)
  static const int tempo = 4;         // Thả người nhanh (Medium)
}

abstract class VUpMetricBase {
  String get name;
  int faultsCount = 0;
  void update(VUpRepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }
  void onStateTransition(VUpState from, VUpState to, int timestampMs) {}
}