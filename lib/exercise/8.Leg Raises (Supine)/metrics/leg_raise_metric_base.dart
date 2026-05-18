import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum LegRaiseState { lying, raising, top, lowering }

class LegRaiseRepContext {
  final double hipFlexionAngle;     // Góc Vai-Hông-Đầu gối (ROM)
  final double kneeStraightnessAngle; // Góc Hông-Đầu gối-Mắt cá (Độ thẳng chân)
  
  final double hipY; // Tọa độ Y của hông để đo độ võng lưng (Pelvic tilt)
  final double ankleY; // Dùng để đo vận tốc khi ở pha TOP
  final double? scaleFactor; // Khoảng cách Shoulder-Hip (chuẩn hóa kích thước)
  
  final LegRaiseState state;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  LegRaiseRepContext({
    required this.hipFlexionAngle,
    required this.kneeStraightnessAngle,
    required this.hipY,
    required this.ankleY,
    required this.scaleFactor,
    required this.state,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

class LegRaiseFaultPriority {
  static const int pelvicInstability = 0; // Võng lưng/Nhấc hông (Critical)
  static const int tempo = 1;             // Thả rơi chân (Critical)
  static const int bentKnee = 2;          // Gập gối (Medium)
  static const int rom = 3;               // Lên chưa đủ cao (Low)
}

abstract class LegRaiseMetricBase {
  String get name;
  int faultsCount = 0;
  void update(LegRaiseRepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }
  void onStateTransition(LegRaiseState from, LegRaiseState to, int timestampMs) {}
}