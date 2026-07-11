// ignore_for_file: annotate_overrides

/* =========================================================================
   JJMetricBase — Abstract base for all jumping jack form metrics.
   
   Each metric is a self-contained unit that:
   - Receives frame data via update()
   - Writes feedback to ctx.resultIssues
   - Logs faults into its own fault list
   - Resets cleanly between reps
   
   Architecture:
   ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
   │ JumpingJack  │────▶│  RepContext   │◀────│  MetricBase  │
   │   (owner)    │     │ (shared state)│     │  (per metric)│
   └──────────────┘     └──────────────┘     └──────────────┘
   
   FRONT VIEW exercise — uses BOTH left + right landmarks simultaneously.
   Scale factor = shoulder width (NOT back length like squat/plank).
   
   Data flow:
   - feedback{}  → cleared every frame in processPose()
                  → metrics write live cards here (Arms, Legs, Tempo)
                  → coaching from evaluateRep() or per-frame faults
                  → cleared when new rep begins (open → closed transition)
   ========================================================================= */

import '../jumping_jack.dart';
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';

/* =========================================================================
   RepContext — Shared per-frame state, passed to all metrics.
   Avoids each metric needing to recalculate the same geometry.
   ========================================================================= */
class RepContext {
  /// Shoulder→Elbow→Wrist angle for left arm (0–180°). 180° = straight.
  final double leftArmAngle;

  /// Shoulder→Elbow→Wrist angle for right arm (0–180°). 180° = straight.
  final double rightArmAngle;

  /// Elevation angle of shoulder→wrist vector from horizontal (degrees).
  /// 0° = arms horizontal, 90° = arms straight overhead.
  final double leftArmElevation;

  /// Elevation angle of shoulder→wrist vector from horizontal (degrees).
  final double rightArmElevation;

  /// Distance between ankles normalized to shoulder width.
  /// ~0.0 = feet together, ~1.5 = good spread.
  final double ankleSpreadNorm;

  /// True if BOTH wrists are above nose Y level.
  final bool wristAboveHead;

  /// True if BOTH wrists are below shoulder Y level.
  final bool wristBelowShoulders;

  /// Current state of the jumping jack cycle.
  final JJState jjState;

  /// Milliseconds since epoch.
  final int frameTimestamp;

  /// Shoulder width in pixels — used as scale factor for front view.
  final double? scaleFactor;

  /// Shared result container — metrics write feedback here.
  final ResultIssues resultIssues;

  RepContext({
    required this.leftArmAngle,
    required this.rightArmAngle,
    required this.leftArmElevation,
    required this.rightArmElevation,
    required this.ankleSpreadNorm,
    required this.wristAboveHead,
    required this.wristBelowShoulders,
    required this.jjState,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.resultIssues,
  });
}

/* =========================================================================
   JJMetricBase — Interface every jumping jack metric implements.
   ========================================================================= */
abstract class JJMetricBase with FaultMetricDebugSource {
  int faultsCount = 0;

  /// Human-readable name for debug/logging.
  String get name;

  /// Called every frame during an active rep.
  /// Writes feedback directly to ctx.resultIssues.
  void update(RepContext ctx);

  /// Faults accumulated this rep. JumpingJack reads these when rep completes.
  List<FaultRecord> get faults;

  /// Debug data for the overlay. Keys should be metric-specific.
  Map<String, dynamic> get debugData;

  /// Reset all internal state for the next rep.
  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  /// Called when JJ state transitions (e.g. closed → open).
  /// Override in metrics that care about transitions (tempo).
  void onStateTransition(JJState from, JJState to, int timestampMs) {}
}
