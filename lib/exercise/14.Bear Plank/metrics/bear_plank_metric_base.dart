import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

// ─── State Machine ───────────────────────────────────────────────────────────
enum BearState { setup, hovering, fatiguing }

// ─── Config ──────────────────────────────────────────────────────────────────
class BearConfig {
  static const double KNEE_HOVER_MIN = 0.04;
  static const double KNEE_HOVER_MAX = 0.30;
  static const double KNEE_ANGLE_SETUP_MIN = 60.0;
  static const double KNEE_ANGLE_SETUP_MAX = 120.0;
  static const double KNEE_ANGLE_BUTT_UP = 140.0;
  static const double BACK_SAG_THRESHOLD = 0.15;
  static const double BACK_ARCH_THRESHOLD = 0.20;
  static const double WEIGHT_SHIFT_THRESHOLD = 0.25;
  static const int TARGET_HOVER_MS = 30000;
  static const int MAX_SESSION_MS = 60000;
}

class BearVoicePriority {
  static const int kneeHover = 1;
  static const int backFlat = 2;
  static const int weightShift = 3;
}

// ─── Context ─────────────────────────────────────────────────────────────────
class BearRepContext {
  final double kneeHeightOffset;
  final double kneeAngle;
  final double backYDifference;
  final double wristXDifference;
  final double? scaleFactor;
  final BearState currentState;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  const BearRepContext({
    required this.kneeHeightOffset,
    required this.kneeAngle,
    required this.backYDifference,
    required this.wristXDifference,
    required this.scaleFactor,
    required this.currentState,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

// ─── Metric Base ─────────────────────────────────────────────────────────────
abstract class BearMetricBase {
  int faultsCount = 0;
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> debugData = {};

  List<FaultRecord> get faults => List.unmodifiable(_faults);

  void update(BearRepContext ctx);
  void onStateTransition(BearState from, BearState to, int timestampMs) {}

  void addFault(FaultRecord fault) => _faults.add(fault);

  void resetAndCountFault() {
    if (_faults.isNotEmpty) faultsCount++;
    _faults.clear();
  }
}
