import '../../exercise_base.dart';
import '../russian_twist.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

class RussianRepContext {
  final double wristX;
  final double wristY;
  final double kneeX;
  final double kneeY;
  final double hipX;
  final double hipY;
  final double shoulderX;
  final double shoulderY;

  final double wristHipDx;
  final double kneeHipDx;
  final double directionMultiplier;

  final RussianTwistState state;
  final TwistDirection direction;
  final int frameTimestamp;
  final ResultIssues resultIssues;

  RussianRepContext({
    required this.wristX,
    required this.wristY,
    required this.kneeX,
    required this.kneeY,
    required this.hipX,
    required this.hipY,
    required this.shoulderX,
    required this.shoulderY,
    required this.wristHipDx,
    required this.kneeHipDx,
    required this.directionMultiplier,
    required this.state,
    required this.direction,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

abstract class RussianMetricBase {
  int _faultsCount = 0;
  final List<FaultRecord> _faults = [];
  Map<String, dynamic> debugData = {};

  int get faultsCount => _faultsCount;
  List<FaultRecord> get faults => List.unmodifiable(_faults);

  void update(RussianRepContext ctx);

  void onStateTransition(RussianTwistState oldState, RussianTwistState newState,
      TwistDirection dir, int timestampMs) {}

  void addFault(FaultRecord fault) {
    if (!_faults.any((f) => f.type == fault.type)) {
      _faults.add(fault);
    }
  }

  void resetAndCountFault() {
    if (_faults.isNotEmpty) {
      _faultsCount++;
    }
    _faults.clear();
    debugData.clear();
  }
}
