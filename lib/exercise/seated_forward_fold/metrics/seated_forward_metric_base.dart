// ignore_for_file: annotate_overrides

import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

class SeatedForwardConfig {
  // Wide real-device bands. The reference capture is approximately hip 35°,
  // knee 159°, spine 151°, and ankle 132° at fold depth.
  static const List<double> Ah_Start_Hip_Angle = [60.0, 170.0];
  static const double Ak_Start_Knee_Angle = 115.0;
  static const double Ak_Fault_Knee_Angle = 125.0;
  static const double As_Fault_Spine_Angle = 95.0;

  static const double Av_Stable_Velocity = 18.0;
  static const int At_Min_Hold_Time = 15;
  // One hold per ExerciseBase instance; the workout session owns the 3 sets.
  static const int At_Num_Holds = 1;

  static const double Ad_Fault_Ankle_Angle = 145.0;
  static const double Ascending_Threshold = 12.0;

  // Ngưỡng góc hông tối thiểu để được phép bắt đầu đếm Hold (Safety Floor)
  static const double Ah_Hold_Safety_Floor = 95.0;
  static const double Ah_Min_Fold_From_Setup = 6.0;
}

enum SeatedForwardState { setup, descending, isometricHold, ascending }

class SeatedForwardContext {
  final double kneeAngle; // Ak
  final double hipAngle; // Ah
  final double hipVelocity; // Av (Độ/giây)
  final double spineAngle; // As
  final double ankleAngle; // Ad
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

abstract class SeatedForwardMetricBase with FaultMetricDebugSource {
  String get name;
  int faultsCount = 0;

  void update(SeatedForwardContext ctx);
  List<FaultRecord> get faults;
  bool get isFaultingNow => false;
  Map<String, dynamic> get debugData;

  void reset() {
    faults.clear();
    debugData.clear();
  }

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(
      SeatedForwardState from, SeatedForwardState to, int timestampMs) {}
}
