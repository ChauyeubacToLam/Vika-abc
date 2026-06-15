import '../../exercise_base.dart';
import '../../fault_record.dart';
import '../../../debug/debug_types.dart';
export '../../../debug/debug_types.dart';
export '../../fault_record.dart';

// ─── State Machine ───────────────────────────────────────────────────────────
enum BearState { setup, hovering, fatiguing }

// ─── Config ──────────────────────────────────────────────────────────────────
class BearConfig {
  static const double KNEE_HOVER_MIN = 0.05;
  static const double KNEE_HOVER_MAX = 0.40;
  static const double KNEE_ANGLE_SETUP_MIN = 60.0;
  static const double KNEE_ANGLE_SETUP_MAX = 120.0;
  static const double KNEE_ANGLE_BUTT_UP = 145.0;
  static const double BACK_SAG_THRESHOLD = 0.15;
  static const double BACK_ARCH_THRESHOLD = 0.20;
  static const double WEIGHT_SHIFT_THRESHOLD = 0.25;
  static const int TARGET_HOVER_MS = 30000;
  static const int MAX_SESSION_MS = 60000;
}

class BearVoicePriority {
  static const int backFlat = 0; // Critical — rủi ro cột sống
  static const int kneeHover = 1; // High — bù trừ cơ
  static const int weightShift = 2; // Medium — áp lực cổ tay
}

// ─── Context ─────────────────────────────────────────────────────────────────
class BearRepContext {
  final double kneeHeightOffset;
  final double kneeAngle;
  final double backYOffset; // Signed: positive = shoulder below hip (sagging)
  final double shoulderWristXOffset; // Abs distance, vai chúi trước cổ tay
  final double? scaleFactor;
  final BearState currentState;
  final int frameTimestampMs;
  final ResultIssues resultIssues;

  const BearRepContext({
    required this.kneeHeightOffset,
    required this.kneeAngle,
    required this.backYOffset,
    required this.shoulderWristXOffset,
    required this.scaleFactor,
    required this.currentState,
    required this.frameTimestampMs,
    required this.resultIssues,
  });
}

// ─── Metric Base ─────────────────────────────────────────────────────────────
abstract class BearMetricBase implements DebugMetricSource {
  int faultsCount = 0;
  bool isFaultingNow = false;
  final List<FaultRecord> _faults = [];
  @override
  final Map<String, dynamic> debugData = {};

  List<FaultRecord> get faults => List.unmodifiable(_faults);
  @override
  String get name => runtimeType.toString();
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

  void update(BearRepContext ctx);
  void onStateTransition(BearState from, BearState to, int timestampMs) {}

  void addFault(FaultRecord fault) => _faults.add(fault);

  void reset() {
    faultsCount = 0;
    isFaultingNow = false;
    _faults.clear();
    debugData.clear();
  }

  void resetAndCountFault() {
    if (_faults.isNotEmpty) faultsCount++;
    isFaultingNow = false;
    _faults.clear();
  }
}
