import '../../exercise_base.dart';
import '../../fault_record.dart';
import '../../../debug/debug_types.dart';

export '../../../debug/debug_types.dart';
export '../../fault_record.dart';

enum BirdDogState { neutral, extending, hold_extended, returning }

class BirdDogTiming {
  static const double holdTargetSeconds = 1.5;
  static const String holdTargetShortLabel = '1.5s';
  static const String holdTargetVoiceLabel = '1 phẩy 5 giây';
}

class BirdDogRepContext {
  final double activeKneeAngle;
  final double nonActiveKneeAngle; // Thêm để chặn lỗi Push-up
  final double activeArmAngle;
  final double shoulderHipAnkleAngle;
  final double trunkHorizontalAngle;
  final double activeArmHorizontalAngle;
  final double activeLegHorizontalAngle;
  final double hipY;
  final double activeAnkleY;
  final double earY; // Thêm để check cúi đầu
  final double shoulderY; // Thêm để check cúi đầu
  final double? scaleFactor;
  final bool isLeftLegActive;
  final bool isLeftArmActive;
  final bool isSameSide; // Thêm để check lỗi cùng tay cùng chân
  final BirdDogState state;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  BirdDogRepContext({
    required this.activeKneeAngle,
    required this.nonActiveKneeAngle,
    required this.activeArmAngle,
    required this.shoulderHipAnkleAngle,
    required this.trunkHorizontalAngle,
    required this.activeArmHorizontalAngle,
    required this.activeLegHorizontalAngle,
    required this.hipY,
    required this.activeAnkleY,
    required this.earY,
    required this.shoulderY,
    required this.scaleFactor,
    required this.isLeftLegActive,
    required this.isLeftArmActive,
    required this.isSameSide,
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

abstract class BirdDogMetricBase implements DebugMetricSource {
  @override
  String get name;
  int faultsCount = 0;

  void update(BirdDogRepContext ctx);

  List<FaultRecord> get faults;
  @override
  Map<String, dynamic> get debugData;

  @override
  double? get value => null;

  @override
  ThresholdBand? get threshold => null;

  @override
  MetricStatus get status {
    if (faults.any((fault) => fault.affectsForm)) {
      return MetricStatus.fault;
    }
    if (faults.isNotEmpty) return MetricStatus.near;
    return MetricStatus.pass;
  }

  @override
  String? get nameVi => null;

  @override
  bool get devOnly => false;

  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  void onStateTransition(BirdDogState from, BirdDogState to, int timestampMs) {}
}
