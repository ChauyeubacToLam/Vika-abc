/* =========================================================================
   LungeMetricBase — Abstract base for all lunge form metrics.
   ========================================================================= */

import '../lunge.dart';
import '../../exercise_base.dart';

/* =========================================================================
   LungeRepContext — Shared per-frame state, passed to all metrics.
   Avoids each metric needing to recalculate the same geometry.
   ========================================================================= */
class LungeRepContext {
  final double leadKneeAngle;
  final double trailKneeAngle;
  final double trunkLean;
  final double heelDistance;
  final double shoulderHipTrailKneeAngle;
  final LungeState lungeState;
  final bool isLeftLegLead;
  final int frameTimestamp; // millisecondsSinceEpoch
  final double? scaleFactor; // Torso length (shoulder-to-hip) for normalization

  // Landmark Y positions (for depth check, etc.)
  final double leadKneeY;
  final double leadHipY;

  /// Shared result container — metrics write feedback + instructions here.
  final ResultIssues resultIssues;

  LungeRepContext({
    required this.leadKneeAngle,
    required this.trailKneeAngle,
    required this.trunkLean,
    required this.heelDistance,
    required this.shoulderHipTrailKneeAngle,
    required this.lungeState,
    required this.isLeftLegLead,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.leadKneeY,
    required this.leadHipY,
    required this.resultIssues,
  });
}

/* =========================================================================
   FaultRecord — A single fault logged by a metric.
   ========================================================================= */
class FaultRecord {
  final String phase; // e.g. "DESCENDING", "BOTTOM"
  final String type; // e.g. "Back", "Depth", "Knees"
  final String message; // e.g. " "
  final bool affectsForm; // false = informational only

  FaultRecord({
    required this.phase,
    required this.type,
    required this.message,
    this.affectsForm = true,
  });
}

/* =========================================================================
   LungeMetricBase — Interface every lunge metric implements.
   ========================================================================= */
abstract class LungeMetricBase {
  /// Human-readable name for debug/logging.
  String get name;

  /// Called every frame during an active rep (lungeState != standing).
  /// Writes feedback + instructions directly to ctx.resultIssues.
  void update(LungeRepContext ctx);

  /// Faults accumulated this rep. Lunge reads these when rep completes.
  List<FaultRecord> get faults;

  /// Debug data for the overlay. Keys should be metric-specific.
  Map<String, dynamic> get debugData;

  /// Reset all internal state for the next rep.
  void reset();

  /// Called when lunge state transitions (e.g. descending → bottom).
  /// Override in metrics that care about transitions (tempo, etc.).
  void onStateTransition(LungeState from, LungeState to, int timestampMs) {}
}
