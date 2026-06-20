/* =========================================================================
   SquatMetricBase — Abstract base for all squat form metrics.
   
   Each metric is a self-contained unit that:
   - Receives frame data via update()
   - Writes feedback + instructions to ctx.resultIssues
   - Logs faults into its own fault list
   - Resets cleanly between reps
   
   Architecture:
   ┌─────────┐     ┌──────────────┐     ┌──────────────┐
   │  Squat  │────▶│  RepContext   │◀────│  MetricBase  │
   │ (owner) │     │ (shared state)│     │  (per metric)│
   └─────────┘     └──────────────┘     └──────────────┘
   
   Data flow:
   - feedback{}  → cleared every frame in processPose()
                  → metrics write live cards here (Depth, Back, Feet, etc.)
   - instructions{phase → {type → message}}
                  → coaching from evaluateRep() or per-frame faults
                  → cleared when new rep begins (standing → descending)
                  → UI reads instructions[currentPhase] for coaching chips
   ========================================================================= */

import '../squat.dart';
import '../../exercise_base.dart';
import '../../fault_record.dart';
import '../../../debug/debug_types.dart';
export '../../../debug/debug_types.dart';
export '../../fault_record.dart'; /* =========================================================================
   RepContext — Shared per-frame state, passed to all metrics.
   Avoids each metric needing to recalculate the same geometry.
   ========================================================================= */

class RepContext {
  final double kneeAngle;
  final double trunkLean; // Positive = forward, negative = backward
  final double clockAngle; // Raw clock angle for trunk
  final double heelDistance; // foot.y - heel.y (raw pixel distance)
  final double? scaleFactor; // Back length (shoulder-to-hip distance)
  final SquatState squatState;
  final int frameTimestamp; // millisecondsSinceEpoch

  // Landmark Y positions (for depth check, sync check, etc.)
  final double kneeY;
  final double hipY;
  final double shoulderY;

  /// Shared result container — metrics write feedback + instructions here.
  final ResultIssues resultIssues;

  RepContext({
    required this.kneeAngle,
    required this.trunkLean,
    required this.clockAngle,
    required this.heelDistance,
    required this.scaleFactor,
    required this.squatState,
    required this.frameTimestamp,
    required this.kneeY,
    required this.hipY,
    required this.shoulderY,
    required this.resultIssues,
  });
}

/// Lower number means the voice cue is more important for post-rep playback.
class SquatFaultVoicePriority {
  static const int heelRise = 0;
  static const int depth = 1;
  static const int trunkLean = 2;
  static const int hipShoulderSync = 3;
  static const int tempo = 4;
  static const int trunkLeanBackward = 5;
}

/* =========================================================================
   SquatMetricBase — Interface every metric implements.
   ========================================================================= */
abstract class SquatMetricBase implements DebugMetricSource {
  /// Human-readable name for debug/logging.
  @override
  String get name;
  // faults count for each metric
  int faultsCount = 0;

  /// Called every frame during an active rep (squatState != standing).
  /// Writes feedback + instructions directly to ctx.resultIssues.
  void update(RepContext ctx);

  /// Faults accumulated this rep. Squat reads these when rep completes.
  List<FaultRecord> get faults;

  /// Debug data for the overlay. Keys should be metric-specific.
  @override
  Map<String, dynamic> get debugData;

  /// Primary threshold-checked scalar shown in the debug panel.
  @override
  double? get value => null;

  /// Warning/fault bounds used by debug sparklines. The metric's own status
  /// remains the source of truth for current pass/near/fault state.
  @override
  ThresholdBand? get threshold => null;

  /// Current metric decision. Override when a metric has a primary value.
  @override
  MetricStatus get status {
    if (faults.any((fault) => fault.affectsForm)) {
      return MetricStatus.fault;
    }
    if (faults.isNotEmpty) return MetricStatus.near;
    return MetricStatus.pass;
  }

  /// Friendly Vietnamese label for user-facing debug mode.
  @override
  String? get nameVi => null;

  /// Hide highly technical metrics from user-facing debug mode.
  @override
  bool get devOnly => false;

  /// Reset all internal state for the next rep.
  void reset();

  /// Reset and count fault
  void resetAndCountFault() {
    if (faults.isNotEmpty) {
      faultsCount++;
    }
    reset();
  }

  /// Called when squat state transitions (e.g. descending → bottom).
  /// Override in metrics that care about transitions (tempo, sync).
  void onStateTransition(SquatState from, SquatState to, int timestampMs) {}
}
