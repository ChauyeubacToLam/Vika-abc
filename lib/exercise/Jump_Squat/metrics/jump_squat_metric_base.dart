// ignore_for_file: constant_identifier_names

import '../jump_squat.dart';
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum JumpSquatState { standing, squatting, launching, airborne, landing }

/* =========================================================================
   RepContext — Shared per-frame state cho Jump Squat.
   ========================================================================= */
class RepContext {
  /// Góc gập gối (Hip -> Knee -> Ankle).
  final double kneeAngle;

  /// Góc nghiêng thân trên so với phương thẳng đứng (độ).
  final double trunkVerticalAngle;

  /// Tọa độ Y của mũi chân (dùng để xác định lơ lửng/tiếp đất).
  /// Trong ML Kit: Y = 0 ở đỉnh màn hình, Y tăng dần xuống dưới.
  final double footY;
  
  /// Tọa độ Y của hông (dùng để xác định hướng di chuyển cơ thể).
  final double hipY;

  final JumpSquatState jumpSquatState;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  RepContext({
    required this.kneeAngle,
    required this.trunkVerticalAngle,
    required this.footY,
    required this.hipY,
    required this.jumpSquatState,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

/* =========================================================================
   JumpSquatMetricBase — Interface cho mọi metric của Jump Squat.
   ========================================================================= */
abstract class JumpSquatMetricBase {
  String get name;
  void update(RepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  void onStateTransition(JumpSquatState from, JumpSquatState to, int timestampMs) {}
}