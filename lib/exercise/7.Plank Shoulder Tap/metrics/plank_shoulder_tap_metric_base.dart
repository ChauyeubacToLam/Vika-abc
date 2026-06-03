// ignore_for_file: constant_identifier_names
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum PlankTapState { base, lifting, tap, returning }

class PlankTapConfig {
  static const int MAX_REP = 20; // 10 rep m
  static const int MAX_DURATION_MS = 90000; // 90s timeout
  static const double CAMERA_45_MIN_RATIO = 0.35;
  static const double CAMERA_45_MAX_RATIO = 0.57;
  // C nh t  chu
  static const List<double> TRUNK_STRAIGHT_RANGE = [170.0, 180.0];

  // C nh State Machine (Normalized Distance: Kho ng c ch C  tay - Vai ch o / Kho ng c ch Vai - H
  static const double LIFT_START_THRESHOLD =
      0.85; // Đã sửa: Nới lỏng để dễ bắt đầu nhấc tay
  static const double TAP_DISTANCE_THRESHOLD =
      0.70; // Đã sửa: Nới lỏng để dễ ghi nhận lúc chạm vai (tránh khuất camera)

  // C c ng ng Metric Y khoa
  static const double HIP_ROTATION_TOLERANCE =
      0.15; // H ng kh ng r t/nh p nh  ~5-7cm (normalized)
  static const double TRUNK_SAG_THRESHOLD = 160.0; // V ng l
  static const double MIN_TAP_TIME =
      0.5; //  t nh t 0.5s cho m t nh p nh c tay  ch ho
}

class PlankTapVoicePriority {
  static const int hipRotation = 0; // Critical (L c xo
  static const int trunkAlignment = 1; // High (V ng l
  static const int clearTap = 2; // Medium ( n gian bi
  static const int tempo = 3; // Medium (T p gi
}

class RepContext {
  final PlankTapState state;
  final int frameTimestamp;
  final double scaleFactor;
  // Angles
  final double trunkAngle; // Vai - H ng - G t (ch n tr
  // Coordinates & Distances
  final double hipY;
  final double
      activeWristShoulderDistNorm; // Kho ng c ch C  tay  ang nh i Vai  i di  chu
  final ResultIssues resultIssues;

  RepContext({
    required this.state,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.trunkAngle,
    required this.hipY,
    required this.activeWristShoulderDistNorm,
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
