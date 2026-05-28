import '../../exercise_base.dart';
import '../../fault_record.dart';

export '../../fault_record.dart';

enum SitUpState { lying, rising, upright, lowering }

class SitUpRepContext {
  final double trunkHorizontalAngle; 
  final double hipKneeAnkleAngle;    
  final double kneeHipShoulderAngle; 
  final double shoulderY; 
  final double ankleY;    
  final double? scaleFactor; 
  final SitUpState state;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  SitUpRepContext({
    required this.trunkHorizontalAngle,
    required this.hipKneeAnkleAngle,
    required this.kneeHipShoulderAngle,
    required this.shoulderY,
    required this.ankleY,
    required this.scaleFactor,
    required this.state,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

class SitUpFaultPriority {
  static const int jerking = 0;   // Giật (Critical)
  static const int heelLift = 1;  // Nhấc chân (High)
  static const int rom = 2;       // Lên chưa tới (Medium)
  static const int tempo = 3;     // Hạ nhanh quá (Medium)
}

abstract class SitUpMetricBase {
  String get name;
  int faultsCount = 0;
  
  void update(SitUpRepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  
  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }
  
  void onStateTransition(SitUpState from, SitUpState to, int timestampMs) {}
}