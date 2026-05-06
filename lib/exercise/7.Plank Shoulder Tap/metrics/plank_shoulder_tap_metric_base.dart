// ignore_for_file: constant_identifier_names
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum PlankTapState { base, lifting, tap, returning }

class PlankTapConfig {
  static const int MAX_REP = 20; // 10 rep mỗi bên
  static const int MAX_DURATION_MS = 90000; // 90s timeout

  // Cấu hình tư thế chuẩn bị
  static const List<double> TRUNK_STRAIGHT_RANGE = [170.0, 180.0];
  
  // Cấu hình State Machine (Normalized Distance: Khoảng cách Cổ tay - Vai chéo / Khoảng cách Vai - Hông)
  static const double LIFT_START_THRESHOLD = 0.8; // Cổ tay rời đất, khoảng cách bắt đầu giảm
  static const double TAP_DISTANCE_THRESHOLD = 0.35; // Cổ tay chạm sát vai đối diện
  
  // Các ngưỡng Metric Y khoa
  static const double HIP_ROTATION_TOLERANCE = 0.15; // Hông không rớt/nhấp nhô quá ~5-7cm (normalized)
  static const double TRUNK_SAG_THRESHOLD = 160.0; // Võng lưng
  static const double MIN_TAP_TIME = 0.5; // Ít nhất 0.5s cho một nhịp nhấc tay để kích hoạt cơ lõi
}

class PlankTapVoicePriority {
  static const int hipRotation = 0; // Critical (Lực xoắn cột sống)
  static const int trunkAlignment = 1; // High (Võng lưng)
  static const int clearTap = 2; // Medium (Ăn gian biên độ)
  static const int tempo = 3; // Medium (Tập giật cục)
}

class RepContext {
  final PlankTapState state;
  final int frameTimestamp;
  final double scaleFactor;

  // Angles
  final double trunkAngle; // Vai - Hông - Gót (chân trụ)
  
  // Coordinates & Distances
  final double hipY; 
  final double activeWristShoulderDistNorm; // Khoảng cách Cổ tay đang nhấc tới Vai đối diện (đã chuẩn hóa)

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
  void onStateTransition(PlankTapState from, PlankTapState to, int timestampMs) {}
  void evaluateRepEnd(RepContext ctx) {}
}