// ignore_for_file: constant_identifier_names

import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum PlankState { forearm_plank, pushing_up, high_plank, lowering }

class PlankConfig {
  static const int MAX_REP = 12; // Mức Intermediate
  static const int MAX_DURATION_MS = 90000; // 90 giây timeout
  
  // Góc cơ thể (Shoulder-Hip-Ankle)
  static const double BODY_ALIGNMENT_START_MIN = 165.0; // Setup (nới lỏng một chút so với 170 để dễ nhận diện)
  static const double BODY_ALIGNMENT_SAG_THRESHOLD = 155.0; // Sụt hông
  
  // Góc tay (Shoulder-Elbow-Wrist)
  static const double ELBOW_FOREARM_MAX = 110.0; // ~90 độ
  static const double ELBOW_PUSHING_THRESHOLD = 105.0;
  static const double ELBOW_HIGH_PLANK_MIN = 155.0; // ~180 độ
  static const double ELBOW_LOWERING_THRESHOLD = 145.0;
  
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
  final double elbowAngle;
  final double hipY;
  final double shoulderY;
  final double? scaleFactor; // Chiều dài vai-hông để chuẩn hóa khoảng cách
  final PlankState currentState;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  PlankRepContext({
    required this.bodyAngle,
    required this.elbowAngle,
    required this.hipY,
    required this.shoulderY,
    required this.scaleFactor,
    required this.currentState,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

abstract class PlankMetricBase {
  String get name;
  int faultsCount = 0;
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;

  void update(PlankRepContext ctx);
  void reset();
  void onStateTransition(PlankState from, PlankState to, int timestampMs) {}
  
  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }
}