/* =========================================================================
   PlankMetricBase — Abstract base for all plank form metrics.
   
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
  /// Signed deviation from horizontal (degrees).
  /// 0° = perfect plank. Positive = sag direction. Negative = pike direction.
  /// (verify sign mapping with debug data)
  final double trunkDeviation;

  /// Ear→Shoulder→Hip angle. 180° = head in line. Deviation = dropped/extended.
  final double neckAngle;

  /// Hip→Knee→Ankle angle. 180° = straight legs. Lower = bent knees.
  /// NULL if ankle not visible (small room / camera too close).
  final double? kneeAngle;

  final PlankState plankState;
  final int frameTimestamp;

  /// Shared result container — metrics write feedback + instructions here.
  final ResultIssues resultIssues;

  RepContext({
    required this.trunkDeviation,
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
  final double faultPercentage; // 0.0–1.0, set at finalizeHold
  final String type; // e.g. "Back", "Neck", "Knees"
  final String message; // e.g. "Hông chùng xuống"
  final bool affectsForm; // false = informational only
  final String? voiceMessage;

  FaultRecord({
    required this.faultPercentage,
    required this.type,
    required this.message,
    this.voiceMessage,
    this.affectsForm = true,
  });
}

/* =========================================================================
   PlankMetricBase — Interface every plank metric implements.
   ========================================================================= */
abstract class PlankMetricBase {
  /// Human-readable name for debug/logging.
  String get name;

  /// Called every frame during an active hold (plankState == holding).
  void update(RepContext ctx);

  /// Faults accumulated this hold.
  List<FaultRecord> get faults;

  /// Debug data for the overlay.
  Map<String, dynamic> get debugData;

  /// Reset all internal state for the next hold.
  void reset();

  /// Called before collecting faults at hold completion.
  /// Metrics that use fault percentage override this.
  void finalizeHold() {}

  /// Called when plank state transitions.
  /// Override if needed (currently no plank metrics use this).
  void onStateTransition(PlankState from, PlankState to, int timestampMs) {}
}
