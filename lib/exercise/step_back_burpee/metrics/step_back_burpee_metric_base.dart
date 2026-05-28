// ignore_for_file: constant_identifier_names
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

// 6 pha liên tiếp của Step-Back Burpee
enum BurpeeState {
  standing,
  squattingDown,
  steppingBack,
  highPlank,
  steppingForward,
  standingUp
}

/* =========================================================================
   RepContext — Shared per-frame state cho Step-Back Burpee
   ========================================================================= */
class RepContext {
  /// Góc khớp gối (Hip-Knee-Ankle) - Kiểm tra lỗi cúi lưng chân thẳng
  final double kneeAngle;

  /// Góc trục thân (Shoulder-Hip-Ankle) - Kiểm tra võng lưng ở Plank
  final double bodyAlignmentAngle;

  /// Góc mở hông (Shoulder-Hip-Knee) - Kiểm tra bước chân đủ dài chưa
  final double hipAngle;

  /// Góc tay (Shoulder-Elbow-Wrist) - Kiểm tra thẳng tay
  final double elbowAngle;

  /// Khoảng cách trục X giữa Cổ tay và Mắt cá (Đo độ dài Plank)
  final double wristAnkleDistX;
  
  /// Tọa độ Y của Cổ tay (Đo việc chạm sàn)
  final double wristY;

  final BurpeeState burpeeState;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  RepContext({
    required this.kneeAngle,
    required this.bodyAlignmentAngle,
    required this.hipAngle,
    required this.elbowAngle,
    required this.wristAnkleDistX,
    required this.wristY,
    required this.burpeeState,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

abstract class StepBackBurpeeMetricBase {
  String get name;
  void update(RepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  void onStateTransition(BurpeeState from, BurpeeState to, int timestampMs) {}
}