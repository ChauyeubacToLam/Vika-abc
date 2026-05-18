// ignore_for_file: constant_identifier_names
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum ReverseCrunchState { lying, curling, top, lowering }

class ReverseCrunchConfig {
  static const int MAX_REP = 15; // Mức độ Intermediate
  static const int MAX_DURATION_MS = 90000; // 90s timeout

  // Setup thresholds
  static const List<double> SETUP_KNEE_ANGLE_RANGE = [80.0, 110.0]; // Khóa gối vuông góc
  static const double LIFT_START_ANGLE_DROP = 5.0; // Góc Vai-Hông-Gối giảm 5 độ -> Bắt đầu cuộn
  
  // Y Khoa (McGill & Sarti) thresholds
  static const double PELVIC_CURL_ANGLE_MIN_DROP = 15.0; // Ở Top, góc Vai-Hông-Gối phải giảm > 15 độ
  static const double HIP_LIFT_MIN_NORMALIZED = 0.05; // Hông phải rời mặt sàn tối thiểu
  
  static const double KNEE_SWING_TOLERANCE = 20.0; // Biên độ dao động tối đa của góc gối (tránh vung chân lấy đà)
  static const double ECCENTRIC_MIN_TIME = 1.5; // Giây: Thời gian hạ hông có kiểm soát
}

class CrunchVoicePriority {
  static const int momentum = 0; // Critical (Vung chân phá cột sống)
  static const int pelvicCurl = 1; // High (Không cuộn mông -> Bài vô nghĩa)
  static const int tempo = 2; // Medium (Hạ quá nhanh)
}

class RepContext {
  final ReverseCrunchState state;
  final int frameTimestamp;
  final double scaleFactor;

  // Angles
  final double trunkKneeAngle; // Vai - Hông - Đầu gối (Góc cuộn bụng)
  final double kneeAngle; // Hông - Đầu gối - Mắt cá (Khóa góc này chống vung)
  
  // Coordinates & Velocity
  final double hipY; 
  final double trunkKneeVelocity; // Vận tốc góc cuộn (Âm = đang gập vào, Dương = đang duỗi ra)

  final ResultIssues resultIssues;

  RepContext({
    required this.state,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.trunkKneeAngle,
    required this.kneeAngle,
    required this.hipY,
    required this.trunkKneeVelocity,
    required this.resultIssues,
  });
}

abstract class ReverseCrunchMetricBase {
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
  void onStateTransition(ReverseCrunchState from, ReverseCrunchState to, int timestampMs) {}
  void evaluateRepEnd(RepContext ctx) {}
}