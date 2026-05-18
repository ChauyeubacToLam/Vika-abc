import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

class SeatedForwardConfig {
  static const List<double> Ah_Start_Hip_Angle = [80.0, 110.0];
  static const double Ak_Start_Knee_Angle = 170.0;
  static const double Ak_Fault_Knee_Angle = 160.0;
  static const double As_Fault_Spine_Angle = 140.0;
  
  static const double Av_Stable_Velocity = 5.0; 
  static const int At_Min_Hold_Time = 15; 
  
  static const double Ad_Fault_Ankle_Angle = 115.0; 
  static const double Ascending_Threshold = 5.0; 

  // Ngưỡng góc hông tối thiểu để được phép bắt đầu đếm Hold (Safety Floor)
  static const double Ah_Hold_Safety_Floor = 70.0; 
}

enum SeatedForwardState { setup, descending, isometricHold, ascending }

class SeatedForwardContext {
  final double kneeAngle;    // Ak
  final double hipAngle;     // Ah
  final double hipVelocity;  // Av (Độ/giây)
  final double spineAngle;   // As
  final double ankleAngle;   // Ad
  final double scaleFactor;  
  final SeatedForwardState state;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  SeatedForwardContext({
    required this.kneeAngle,
    required this.hipAngle,
    required this.hipVelocity,
    required this.spineAngle,
    required this.ankleAngle,
    required this.scaleFactor,
    required this.state,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

class SeatedForwardFaultVoicePriority {
  static const int kneeBent = 0;   
  static const int spineRound = 1; 
  static const int ankleDorsi = 2; 
  static const int holdTempo = 3;  
}

abstract class SeatedForwardMetricBase {
  String get name;
  int faultsCount = 0;

  void update(SeatedForwardContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;

  void reset() {
    faults.clear();
    debugData.clear();
  }

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(SeatedForwardState from, SeatedForwardState to, int timestampMs) {}
}