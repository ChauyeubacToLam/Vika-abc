import '../../exercise_base.dart';
import '../../fault_record.dart';

export '../../fault_record.dart';

enum BirdDogState { neutral, extending, hold_extended, returning }

class BirdDogRepContext {
  final double activeKneeAngle;       
  final double activeArmAngle;        
  final double shoulderHipAnkleAngle; 
  final double trunkHorizontalAngle;  
  final double activeArmHorizontalAngle; 
  final double activeLegHorizontalAngle; 
  final double hipY; 
  final double? scaleFactor; 
  final bool isLeftLegActive; 
  final BirdDogState state;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  BirdDogRepContext({
    required this.activeKneeAngle,
    required this.activeArmAngle,
    required this.shoulderHipAnkleAngle,
    required this.trunkHorizontalAngle,
    required this.activeArmHorizontalAngle,
    required this.activeLegHorizontalAngle,
    required this.hipY,
    required this.scaleFactor,
    required this.isLeftLegActive,
    required this.state,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

class BirdDogFaultPriority {
  static const int lumbarExtension = 0; 
  static const int trunkStability = 1;  
  static const int tempo = 2;           
  static const int alignment = 3;       
}

abstract class BirdDogMetricBase {
  String get name;
  int faultsCount = 0;

  void update(BirdDogRepContext ctx);

  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;

  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(BirdDogState from, BirdDogState to, int timestampMs) {}
}