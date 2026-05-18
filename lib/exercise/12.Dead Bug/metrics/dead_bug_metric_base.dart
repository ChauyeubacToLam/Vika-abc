import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum DeadBugState { setup, extending, hold, returning }

class DeadBugRepContext {
  final double leftArmAngle;  // Góc Hip-Shoulder-Wrist (Trái)
  final double rightArmAngle; // Góc Hip-Shoulder-Wrist (Phải)
  final double leftHipAngle;  // Góc Shoulder-Hip-Knee (Trái)
  final double rightHipAngle; // Góc Shoulder-Hip-Knee (Phải)
  
  final double hipY; // Tọa độ Y hông (để tính võng lưng)
  final double shoulderY; // Tọa độ Y vai
  final double? scaleFactor; // Khoảng cách Shoulder-Hip để chuẩn hóa
  
  final DeadBugState state;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  DeadBugRepContext({
    required this.leftArmAngle,
    required this.rightArmAngle,
    required this.leftHipAngle,
    required this.rightHipAngle,
    required this.hipY,
    required this.shoulderY,
    required this.scaleFactor,
    required this.state,
    required this.frameTimestampMs,
    required this.resultIssues,
  });

  // Helper để lấy góc duỗi lớn nhất trong 4 chi (Dùng cho State Machine)
  double get maxExtensionAngle {
    return [leftArmAngle, rightArmAngle, leftHipAngle, rightHipAngle].reduce((a, b) => a > b ? a : b);
  }
}

class DeadBugFaultPriority {
  static const int antiExtension = 0; // Võng lưng (Critical)
  static const int coordination = 1;  // Đi cùng bên (High)
  static const int stableLimbs = 2;   // Chi trụ bị xê dịch (Medium)
  static const int tempo = 3;         // Thả rơi nhanh (Medium)
}

abstract class DeadBugMetricBase {
  String get name;
  int faultsCount = 0;
  void update(DeadBugRepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }
  void onStateTransition(DeadBugState from, DeadBugState to, int timestampMs) {}
}