import '../../exercise_base.dart';
import '../../fault_record.dart';
import '../../../debug/debug_types.dart';
export '../../../debug/debug_types.dart';
export '../../fault_record.dart';

// ─── State Machine ───────────────────────────────────────────────────────────
enum SupermanState { setup, lifting, hold, lowering }

// ─── Config ──────────────────────────────────────────────────────────────────
class SupermanConfig {
  static const double LIFT_THRESHOLD = 0.04;
  static const double LOWERED_THRESHOLD = 0.025;
  static const double HOLD_MIN_MS = 1500.0;
  static const double SPINE_NEUTRAL_RANGE = 15.0;
  static const double LUMBAR_EXTENSION_DANGER = 25.0;
  static const int MAX_REP = 12;
  static const int MAX_DURATION_MS = 120000;
}

class SupermanVoicePriority {
  static const int lumbarExtension = 1;
  static const int hipGrounding = 2;
  static const int holdTime = 3;
  static const int limbElevation = 4; // Fix #8: Đã thêm constant
}

// ─── Context ─────────────────────────────────────────────────────────────────
class SupermanRepContext {
  final double armElevation;
  final double legElevation;
  final double hipElevation; // Fix #5: Đã thêm field hipElevation
  final double spineAngle;
  final double? scaleFactor;
  final SupermanState currentState;
  final int frameTimestampMs;
  final ResultIssues resultIssues;
  // Aliases for old metrics
  double get trunkAngle => spineAngle;
  SupermanState get state => currentState;

  const SupermanRepContext({
    required this.armElevation,
    required this.legElevation,
    required this.hipElevation,
    required this.spineAngle,
    required this.scaleFactor,
    required this.currentState,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

// ─── Metric Base ─────────────────────────────────────────────────────────────
abstract class SupermanMetricBase implements DebugMetricSource {
  int faultsCount = 0;
  final List<FaultRecord> _faults = [];
  @override
  final Map<String, dynamic> debugData = {};

  List<FaultRecord> get faults => List.unmodifiable(_faults);
  @override
  String get name;
  @override
  double? get value => null;
  @override
  ThresholdBand? get threshold => null;
  @override
  MetricStatus get status => MetricStatus.pass;
  @override
  String? get nameVi => null;
  @override
  bool get devOnly => false;

  void update(SupermanRepContext ctx);
  void onStateTransition(
      SupermanState from, SupermanState to, int timestampMs) {}
  void evaluateRepEnd(SupermanRepContext ctx) {}

  void addFault(FaultRecord fault) => _faults.add(fault);

  void resetAndCountFault() {
    if (_faults.isNotEmpty) faultsCount++;
    _faults.clear();
  }

  void reset() {
    _faults.clear();
  }
}
