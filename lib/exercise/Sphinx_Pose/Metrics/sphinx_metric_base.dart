// ignore_for_file: constant_identifier_names, annotate_overrides
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

// --- Quy định danh: Các biến thuật toán 'A', ký tự 2 duy nhất ---
class SphinxConfig {
  static const double Aa_Start_Body_Angle = 160.0;
  static const List<double> Ab_Elbow_Hold_Angle = [55.0, 135.0];
  static const List<double> Ac_Spine_Ext_Angle = [115.0, 180.0];
  static const double Ad_Hip_Ground_Tol = 0.25;
  static const int Ae_Min_Hold_Time = 2;
  static const int Af_Max_Reps = 1;
  static const double Ag_Neck_Shrug_Tol = 0.14;
  static const double Ah_Stability_Var = 35.0;
  // [Fix Gap 1]: Ngưỡng phát hiện ngửa cổ (hyperextension).
  // neckAngle = góc Tai - Vai - Hông. Khi nằm trung tính ~160-170
  // Nếu < 140 là ngửa ra sau quá nhiều so với ngực
  static const double Ai_Neck_Hyper_Tol = 125.0;
  static const double Aj_Forearm_Horiz_Tol = 42.0;
  static const double Ak_UpperArm_Vert_Tol = 75.0;
}

enum SphinxState { proneSetup, ascending, isometricHold, descending }

class SphinxContext {
  final double bodyAngle;
  final double elbowAngle;
  final double spineAngle;
  final double forearmAngle;
  final double upperArmAngle;
  final double hipY;
  final double ankleY;
  final double earShoulderDist;
  final double neckAngle;
  final double scaleFactor;
  final SphinxState state;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  SphinxContext({
    required this.bodyAngle,
    required this.elbowAngle,
    required this.spineAngle,
    required this.forearmAngle,
    required this.upperArmAngle,
    required this.hipY,
    required this.ankleY,
    required this.earShoulderDist,
    required this.neckAngle,
    required this.scaleFactor,
    required this.state,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

class SphinxFaultVoicePriority {
  static const int hipLift = 0; // Nâng hông / mất decompression
  static const int straightArm = 1; // Lỗi form Cobra
  static const int shrugNeck = 2; // Rụt cổ / mỏi vai gáy
  static const int neckHyper = 3; // Ngửa cổ
}

abstract class SphinxMetricBase with FaultMetricDebugSource {
  String get name;
  int faultsCount = 0;
  void update(SphinxContext ctx);
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

  void onStateTransition(SphinxState from, SphinxState to, int timestampMs) {}
}
