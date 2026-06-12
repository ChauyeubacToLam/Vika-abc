// ignore_for_file: constant_identifier_names
import '../../exercise_base.dart';
import '../../fault_record.dart';

export '../../fault_record.dart';

enum BowPoseState { prone, setup, ascending, hold, descending }

class RepContext {
  final double referenceLength; // Khoảng cách Vai - Hông (Base body length)
  final double thighLength; // Khoảng cách Hông - Đầu gối
  final double rawShoulderY; // Tọa độ Y thô của vai để check việc "dâng lên"

  final double wristAnkleDist; // Đã chuẩn hóa theo referenceLength
  final double chestLift; // Đã chuẩn hóa theo referenceLength
  final double thighLiftRelative; // Đã chuẩn hóa theo thighLength
  final double kneeAngle;

  final BowPoseState bowPoseState;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  RepContext({
    required this.referenceLength,
    required this.thighLength,
    required this.rawShoulderY,
    required this.wristAnkleDist,
    required this.chestLift,
    required this.thighLiftRelative,
    required this.kneeAngle,
    required this.bowPoseState,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

abstract class BowPoseMetricBase {
  int faultsCount = 0;

  String get name;
  void update(RepContext ctx);
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  void reset();
  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(BowPoseState from, BowPoseState to, int timestampMs) {}
  void evaluateRep(RepContext ctx) {}
}
