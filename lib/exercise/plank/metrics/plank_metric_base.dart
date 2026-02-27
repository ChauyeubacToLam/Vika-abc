/* =========================================================================
   PlankMetricBase — Abstract base for all plank form metrics.
   
   Same architecture as SquatMetricBase but adapted for plank:
   - RepContext carries plank-specific angles (back, neck, knee)
   - No movement phases — metrics fire continuously during holding
   - Faults accumulate per-hold, reset between holds
   
   Architecture:
   ┌─────────┐     ┌──────────────┐     ┌──────────────┐
   │  Plank  │────▶│  RepContext   │◀────│  MetricBase  │
   │ (owner) │     │ (shared state)│     │  (per metric)│
   └─────────┘     └──────────────┘     └──────────────┘
   ========================================================================= */

import '../plank.dart';
import '../../exercise_base.dart';

/* =========================================================================
   RepContext — Shared per-frame state for plank metrics.
   ========================================================================= */
class RepContext {
  /// Shoulder→Hip→Ankle angle. 180° = straight. >180° = sag. <180° = pike.
  /// NOTE: Exact behavior depends on calculateAngle() — verify with debug data.
  final double backAngle;

  /// Ear→Shoulder→Hip angle. 180° = head in line. Deviation = dropped/extended.
  final double neckAngle;

  /// Hip→Knee→Ankle angle. 180° = straight legs. Lower = bent knees.
  final double kneeAngle;

  final PlankState plankState;
  final int frameTimestamp;

  /// Shared result container — metrics write feedback + instructions here.
  final ResultIssues resultIssues;

  RepContext({
    required this.backAngle,
    required this.neckAngle,
    required this.kneeAngle,
    required this.plankState,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

/* =========================================================================
   FaultRecord — A single fault logged by a metric.
   ========================================================================= */
class FaultRecord {
  final double
      faultPercentage; // For percentage-based metrics, otherwise can be 1.0
  final String type; // e.g. "Back", "Neck", "Knees"
  final String message; // e.g. "Hông chùng xuống"
  final bool affectsForm; // false = informational only

  FaultRecord({
    required this.faultPercentage,
    required this.type,
    required this.message,
    this.affectsForm = true,
  });
}

/* =========================================================================
   PlankMetricBase — Interface every plank metric implements.
   ========================================================================= */
abstract class PlankMetricBase {
  /// Human-readable name for debug/logging.
  String get name;

  /// Called before collecting faults at hold completion.
  /// Metrics that use fault percentage override this.
  void finalizeHold() {}

  /// Called every frame during an active hold (plankState == holding).
  /// Writes feedback + instructions directly to ctx.resultIssues.
  void update(RepContext ctx);

  /// Faults accumulated this hold. Plank reads these when hold completes.
  List<FaultRecord> get faults;

  /// Debug data for the overlay. Keys should be metric-specific.
  Map<String, dynamic> get debugData;

  /// Reset all internal state for the next hold.
  void reset();
}
