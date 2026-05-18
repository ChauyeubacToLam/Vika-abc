// ignore_for_file: constant_identifier_names
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

// --- Enum & Config ---
enum ClimberState { high_plank_base, knee_driving_in, max_flexion, knee_driving_out }

class ClimberConfig {
  static const int MAX_REP = 30; // 15 mỗi chân
  static const int MAX_DURATION_MS = 90000; // 90s timeout

  static const double ARM_STRAIGHT_THRESHOLD = 160.0;
  static const List<double> TRUNK_STRAIGHT_RANGE = [160.0, 180.0];
  
  static const double HIP_DROP_THRESHOLD = 160.0; // Võng lưng
  static const double HIP_BOUNCE_TOLERANCE_NORMALIZED = 0.15; // Nhấp nhô hông ~ 10cm
  
  static const double KNEE_VELOCITY_THRESHOLD = 0.05; // Ngưỡng xác định chân bắt đầu di chuyển
}

class ClimberVoicePriority {
  static const int trunkStability = 0; // Võng lưng/Nhấp nhô là quan trọng nhất
  static const int kneeRom = 1;
  static const int pace = 2;
}

// --- Rep Context ---
class RepContext {
  final ClimberState state;
  final int frameTimestamp;
  final double scaleFactor; // Khoảng cách Vai - Hông

  // Angles
  final double armAngle; // Vai - Khuỷu - Cổ tay
  final double trunkAngle; // Vai - Hông - Gót (chân trụ)
  
  // Coordinates for tracking
  final double hipY; // Theo dõi nhấp nhô
  final double shoulderX;
  final double hipX;
  final double activeKneeX; // Chân đang co
  final double activeKneeXVelocity; // Vận tốc trục X của gối (âm = tiến lên, dương = lùi về, tùy góc cam)

  final ResultIssues resultIssues;

  RepContext({
    required this.state,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.armAngle,
    required this.trunkAngle,
    required this.hipY,
    required this.shoulderX,
    required this.hipX,
    required this.activeKneeX,
    required this.activeKneeXVelocity,
    required this.resultIssues,
  });
}

abstract class ClimberMetricBase {
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
  void onStateTransition(ClimberState from, ClimberState to, int timestampMs) {}
}