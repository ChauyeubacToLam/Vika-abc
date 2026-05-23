import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

class LegRaiseConfig {
  static const int MAX_REP = 12; // Beginner/Conservative
  static const int TIMEOUT_MS = 90000; // 90s
  
  // Start Position Limits
  static const double START_HIP_FLEXION_MIN = 165.0; // Gần 180 độ
  static const double START_KNEE_STRAIGHT_MIN = 160.0; // Phải duỗi gối

  // State Transition Thresholds
  static const double RAISING_ANGLE = 170.0;
  static const double TOP_ANGLE = 100.0; // Vai-Hông-Gối <= 100 độ
  static const double LOWERING_ANGLE = 105.0;
  static const double LYING_ANGLE = 165.0;

  // Tempo Thresholds (Unified: fault if < 2.0s, target if >= 2.0s)
  static const double TEMPO_FAULT_THRESHOLD = 2.0;
  static const double TEMPO_TARGET_THRESHOLD = 2.0;
  
  // Trunk Angle Limit
  static const double MAX_TRUNK_ANGLE = 45.0;
}

enum LegRaiseState { lying, raising, top, lowering }

class LegRaiseRepContext {
  final double hipFlexionAngle;     // Góc Vai-Hông-Đầu gối (ROM)
  final double kneeStraightnessAngle; // Góc Hông-Đầu gối-Mắt cá (Độ thẳng chân)
  final double trunkHorizontalAngle; // Góc ngang của thân người (chống gian lận bằng cách ngồi dậy)
  
  final double hipY; // Tọa độ Y của hông để đo độ võng lưng (Pelvic tilt)
  final double ankleY; // Dùng để đo vận tốc khi ở pha TOP
  final double scaleFactor; // Khoảng cách Shoulder-Hip (chuẩn hóa kích thước)
  
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
    required this.state,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

class LegRaiseFaultPriority {
  static const int pelvicInstability = 0; // Võng lưng/Nhấc hông (Critical)
  static const int tempo = 1;             // Thả rơi chân (Critical)
  static const int bentKnee = 2;          // Gập gối (Medium)
  static const int rom = 3;               // Lên chưa đủ cao (Low)
}

abstract class LegRaiseMetricBase {
  String get name;
  int faultsCount = 0;
  void update(LegRaiseRepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }
  void onStateTransition(LegRaiseState from, LegRaiseState to, int timestampMs) {}
}