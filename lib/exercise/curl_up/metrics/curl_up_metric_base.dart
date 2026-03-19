/* =========================================================================
   CurlUpMetricBase — Abstract base for all curl-up form metrics.
   ========================================================================= */

import '../curl_up.dart';
import '../../exercise_base.dart';

/* =========================================================================
   RepContext — Shared per-frame state, passed to all metrics.
   Avoids each metric needing to recalculate the same geometry.
   ========================================================================= */
class RepContext {
  final double trunkAngle; // Degrees from horizontal (0 = flat, + = curling up)
  final double
      shoulderHipKneeAngle; // Interior angle at hip (Shoulder-Hip-Knee)
  final double
      earShoulderHipAngle; // Interior angle at shoulder (Ear-Shoulder-Hip)
  final double?
      hipKneeAnkleAngle; // Bent-leg knee angle — min(left, right) to always track the bent knee
  final double? scaleFactor;
  final CurlUpState curlUpState;
  final int frameTimestamp; // millisecondsSinceEpoch
  final double? holdStillEarShoulderHip;
  final double? holdStillShoulderHipKnee;

  final double shoulderY;
  final double hipY;
  final double kneeY;

  /// Shared result container — metrics write feedback + instructions here.
  final ResultIssues resultIssues;

  RepContext({
    required this.trunkAngle,
    required this.shoulderHipKneeAngle,
    required this.earShoulderHipAngle,
    required this.hipKneeAnkleAngle,
    required this.scaleFactor,
    required this.curlUpState,
    required this.frameTimestamp,
    required this.shoulderY,
    required this.hipY,
    required this.kneeY,
    required this.resultIssues,
    this.holdStillEarShoulderHip,
    this.holdStillShoulderHipKnee,
  });
}

/* =========================================================================
   FaultRecord — A single fault logged by a metric.
   ========================================================================= */
class FaultRecord {
  final String phase; // e.g. "ASCENDING", "APEX"
  final String type; // e.g. "Neck", "Range", "Knee"
  final String message; // e.g. "Kéo cổ quá mạnh"
  final bool affectsForm; // false = informational only

  FaultRecord({
    required this.phase,
    required this.type,
    required this.message,
    this.affectsForm = true,
  });
}

/* =========================================================================
   CurlUpMetricBase — Interface every metric implements.
   ========================================================================= */
abstract class CurlUpMetricBase {
  /// Human-readable name for debug/logging.
  String get name;

  /// Called every frame during an active rep (curlUpState != resting).
  /// Writes feedback + instructions directly to ctx.resultIssues.
  void update(RepContext ctx);

  /// Faults accumulated this rep. CurlUp reads these when rep completes.
  List<FaultRecord> get faults;

  /// Debug data for the overlay. Keys should be metric-specific.
  Map<String, dynamic> get debugData;

  /// Reset all internal state for the next rep.
  void reset();

  /// Called every frame while in the resting state (before rep starts).
  /// Override in metrics that sample a personal baseline from lying frames.
  void onRestingFrame(RepContext ctx) {}

  /// Called when curl-up state transitions (e.g. ascending → apex).
  /// Override in metrics that care about transitions.
  void onStateTransition(CurlUpState from, CurlUpState to, int timestampMs) {}
}
