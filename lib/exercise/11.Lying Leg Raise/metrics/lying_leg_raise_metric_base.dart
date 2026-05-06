// ignore_for_file: constant_identifier_names
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum LyingLegRaiseState { lying, raising, top, lowering }

class LegRaiseConfig {
  static const int MAX_REP = 15; // "Chất lượng hơn số lượng"
  static const int MAX_DURATION_MS = 90000; // 90s timeout

  // Cấu hình tư thế chuẩn bị
  static const double TRUNK_FLAT_TOLERANCE = 15.0; // Góc lệch tối đa của thân so với phương ngang
  static const double KNEE_STRAIGHT_SETUP = 160.0; // Duỗi gối khi bắt đầu
  
  // State Machine thresholds
  static const double LIFT_START_ANGLE = 15.0; // Góc chân > 15 độ tính là bắt đầu nâng
  static const double VELOCITY_ZERO_TOLERANCE = 2.0; // Vận tốc góc = 0 (Đỉnh)
  
  // Y Khoa thresholds
  static const double LUMBAR_ARCH_TOLERANCE = 0.08; // Normalized Y variance của hông (nhấc hông/võng lưng)
  static const double TOP_ANGLE_MIN_GOOD = 80.0; // Chân vuông góc sàn (80-90 độ)
  static const double TOP_ANGLE_ERROR = 70.0; // Dưới 70 độ là ăn gian
  static const double ECCENTRIC_MIN_TIME = 1.2; // Tối thiểu 1.2s hạ chân (Không thả rơi)
}

class LegRaiseVoicePriority {
  static const int lumbarArch = 0; // Critical (Võng lưng phá đĩa đệm)
  static const int eccentricTempo = 1; // High (Thả rơi chân tự do)
  static const int rom = 2; // Medium (Không nâng đủ cao)
  static const int kneeStraight = 3; // Medium (Gập gối ăn gian đòn bẩy)
}

class RepContext {
  final LyingLegRaiseState state;
  final int frameTimestamp;
  final double scaleFactor;

  // Angles
  final double trunkHorizontalAngle; // Góc Vai-Hông so với phương ngang (Mặt sàn)
  final double legHorizontalAngle; // Góc Hông-Mắt cá so với phương ngang (Biên độ nâng)
  final double kneeAngle; // Hông-Gối-Mắt cá
  
  // Coordinates & Velocity
  final double hipY; 
  final double legAngularVelocity; // Vận tốc góc nâng chân (độ/giây)

  final ResultIssues resultIssues;

  RepContext({
    required this.state,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.trunkHorizontalAngle,
    required this.legHorizontalAngle,
    required this.kneeAngle,
    required this.hipY,
    required this.legAngularVelocity,
    required this.resultIssues,
  });
}

abstract class LyingLegRaiseMetricBase {
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
  void onStateTransition(LyingLegRaiseState from, LyingLegRaiseState to, int timestampMs) {}
  void evaluateRepEnd(RepContext ctx) {}
}