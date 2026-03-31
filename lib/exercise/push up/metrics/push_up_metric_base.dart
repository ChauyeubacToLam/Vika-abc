/* =========================================================================
   PushUpMetricBase — Abstract base for all push-up form metrics.
   
   Architecture mirrors SquatMetricBase exactly:
   ┌──────────┐     ┌──────────────┐     ┌──────────────┐
   │  PushUp  │────▶│  RepContext   │◀────│  MetricBase  │
   │ (owner)  │     │ (shared state)│     │  (per metric)│
   └──────────┘     └──────────────┘     └──────────────┘
   
   Data flow:
   - feedback{}  → cleared every frame in processPose()
                  → metrics write live cards here (Back, Depth, Tempo)
   - instructions{phase → {type → message}}
                  → coaching from per-frame faults or rep evaluation
                  → cleared when new rep begins (plank → descending)
                  → UI reads instructions[currentPhase] for coaching chips
   ========================================================================= */

import '../push_up.dart';
import '../../exercise_base.dart';

/* =========================================================================
   RepContext — Shared per-frame state, passed to all metrics.
   Avoids each metric needing to recalculate the same geometry.
   ========================================================================= */
class RepContext {
  /// Elbow angle β: SHOULDER→ELBOW→WRIST. Drives state machine.
  /// ~170° at top (plank), ~90° at bottom.
  final double elbowAngle;

  /// Trunk deviation from horizontal (degrees).
  /// 0° = perfect horizontal. Positive = sag. Negative = pike.
  /// Uses same clock-angle-to-deviation math as Plank.
  final double trunkDeviation;

  /// Raw clock angle of shoulder-hip line (for debug).
  final double trunkClockAngle;

  final double? scaleFactor; // Back length (shoulder-to-hip distance)
  final PushUpState pushUpState;
  final int frameTimestamp; // millisecondsSinceEpoch

  /// Shared result container — metrics write feedback + instructions here.
  final ResultIssues resultIssues;

  RepContext({
    required this.elbowAngle,
    required this.trunkDeviation,
    required this.trunkClockAngle,
    required this.scaleFactor,
    required this.pushUpState,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

/* =========================================================================
   FaultRecord — A single fault logged by a metric.
   Same structure as squat's FaultRecord.
   ========================================================================= */
class FaultRecord {
  final String phase; // e.g. "DESCENDING", "BOTTOM"
  final String type; // e.g. "Back", "Depth", "Tempo"
  final String message; // e.g. "Leaned too forward"
  final bool affectsForm; // false = informational only (like heel rise)
  final String? voiceMessage;

  FaultRecord({
    required this.phase,
    required this.type,
    required this.message,
    this.voiceMessage,
    this.affectsForm = true,
  });
}

/* =========================================================================
   PushUpMetricBase — Interface every push-up metric implements.
   ========================================================================= */
abstract class PushUpMetricBase {
  /// Human-readable name for debug/logging.
  String get name;

  /// Called every frame during an active rep (pushUpState != plank).
  /// Writes feedback + instructions directly to ctx.resultIssues.
  void update(RepContext ctx);

  /// Faults accumulated this rep.
  List<FaultRecord> get faults;

  /// Debug data for the overlay. Keys should be metric-specific.
  Map<String, dynamic> get debugData;

  /// Reset all internal state for the next rep.
  void reset();

  /// Called when push-up state transitions (e.g. descending → bottom).
  /// Override in metrics that care about transitions (tempo).
  void onStateTransition(PushUpState from, PushUpState to, int timestampMs) {}
}
