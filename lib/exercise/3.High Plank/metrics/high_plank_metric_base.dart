import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

enum HighPlankState { setup, holding, dropping }

class HighPlankRepContext {
  final double shoulderHipAnkleAngle; // Đo thẳng người
  final double shoulderElbowWristAngle; // Đo tay duỗi
  
  final double hipDeviation; // Khoảng cách hông so với đường chuẩn (Dương = Sụt hông, Âm = Chổng mông)
  final double? scaleFactor; // Khoảng cách Shoulder-Hip để chuẩn hóa
  
  final HighPlankState state;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  HighPlankRepContext({
    required this.shoulderHipAnkleAngle,
    required this.shoulderElbowWristAngle,
    required this.hipDeviation,
    required this.scaleFactor,
    required this.state,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

class HighPlankFaultPriority {
  static const int hipSagging = 0; // Võng lưng (Critical)
  static const int bentElbows = 1; // Cong tay (High)
  static const int pikedHips = 2;  // Chổng mông (Medium)
}

abstract class HighPlankMetricBase {
  String get name;
  int faultsCount = 0;
  void update(HighPlankRepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }
  void onStateTransition(HighPlankState from, HighPlankState to, int timestampMs) {}
}