// ignore_for_file: constant_identifier_names, annotate_overrides
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum ReverseCrunchState { lying, curling, top, lowering }

class ReverseCrunchConfig {
  static const int MAX_REP = 15; // Mức độ Intermediate
  static const int MAX_DURATION_MS = 90000; // 90s timeout

  // Setup thresholds
  static const List<double> SETUP_KNEE_ANGLE_RANGE = [
    60.0,
    130.0
  ]; // Mở rộng góc gối để dễ setup
  static const double SETUP_TRUNK_HORIZONTAL_MAX = 28.0;
  static const double SETUP_THIGH_VERTICAL_MIN = 50.0;
  static const double SETUP_SHIN_HORIZONTAL_MAX = 40.0;
  static const double LIFT_START_ANGLE_DROP =
      6.0; // Góc Vai-Hông-Gối giảm 5 độ -> Bắt đầu cuộn
  static const double LIFT_START_HIP_LIFT_NORMALIZED = 0.03;

  // Y Khoa (McGill & Sarti) thresholds
  static const double PELVIC_CURL_ANGLE_MIN_DROP =
      7.0; // Ở Top, góc Vai-Hông-Gối phải giảm > 15 độ
  static const double HIP_LIFT_MIN_NORMALIZED =
      0.02; // Hông phải rời mặt sàn tối thiểu
  static const double HIP_LIFT_EXIT_DROP_NORMALIZED = 0.012;
  static const double RETURN_ANGLE_RISE = 5.0;
  static const double PEAK_KNEE_EXTENSION_MIN = 138.0;
  static const double PEAK_LEG_VERTICAL_MIN = 55.0;
  static const double PEAK_EXIT_LEG_VERTICAL_MIN = 45.0;
  static const double PEAK_EXIT_KNEE_EXTENSION_MIN = 130.0;
  static const double EARLY_KICK_KNEE_EXTENSION_MIN = 135.0;

  static const double KNEE_SWING_TOLERANCE =
      28.0; // Biên độ dao động tối đa của góc gối (tránh vung chân lấy đà)
  static const double ECCENTRIC_MIN_TIME =
      1.0; // Giây: Thời gian hạ hông có kiểm soát
  // Arm position: elbows straight, wrists kept beside the hips.
  static const double ARM_ELBOW_STRAIGHT_MIN = 135.0;
  static const double ARM_WRIST_HIP_MAX_RATIO = 0.95;
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
  final double thighHorizontalAngle;
  final double shinHorizontalAngle;
  final double legHorizontalAngle;

  // Coordinates & Velocity
  final double hipY;
  final double hipLiftNormalized;
  final double
      trunkKneeVelocity; // Vận tốc góc cuộn (Âm = đang gập vào, Dương = đang duỗi ra)
  final bool isSetupPosition;
  final bool isContractionPosition;
  final bool isLegThrustPeak;

  final bool armsVisible;
  final double? armStraightnessAngle;
  final double? wristHipDistanceRatio;

  final ResultIssues resultIssues;

  RepContext({
    required this.state,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.trunkKneeAngle,
    required this.kneeAngle,
    required this.thighHorizontalAngle,
    required this.shinHorizontalAngle,
    required this.legHorizontalAngle,
    required this.hipY,
    required this.hipLiftNormalized,
    required this.trunkKneeVelocity,
    required this.isSetupPosition,
    required this.isContractionPosition,
    required this.isLegThrustPeak,
    required this.armsVisible,
    required this.armStraightnessAngle,
    required this.wristHipDistanceRatio,
    required this.resultIssues,
  });

  RepContext copyWith({ReverseCrunchState? state}) {
    return RepContext(
      state: state ?? this.state,
      frameTimestamp: frameTimestamp,
      scaleFactor: scaleFactor,
      trunkKneeAngle: trunkKneeAngle,
      kneeAngle: kneeAngle,
      thighHorizontalAngle: thighHorizontalAngle,
      shinHorizontalAngle: shinHorizontalAngle,
      legHorizontalAngle: legHorizontalAngle,
      hipY: hipY,
      hipLiftNormalized: hipLiftNormalized,
      trunkKneeVelocity: trunkKneeVelocity,
      isSetupPosition: isSetupPosition,
      isContractionPosition: isContractionPosition,
      isLegThrustPeak: isLegThrustPeak,
      armsVisible: armsVisible,
      armStraightnessAngle: armStraightnessAngle,
      wristHipDistanceRatio: wristHipDistanceRatio,
      resultIssues: resultIssues,
    );
  }
}

abstract class ReverseCrunchMetricBase with FaultMetricDebugSource {
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
      ReverseCrunchState from, ReverseCrunchState to, int timestampMs) {}
  void evaluateRepEnd(RepContext ctx) {}
}
