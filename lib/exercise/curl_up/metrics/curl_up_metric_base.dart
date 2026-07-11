/* =========================================================================
   CurlUpMetricBase — Abstract base for all curl-up form metrics.

   Each metric is a self-contained unit that:
   - Receives frame data via update() (active rep) or onRestingFrame() (between reps)
   - Writes feedback to ctx.resultIssues
   - Logs faults into its own fault list
   - Resets cleanly between reps

   Architecture (mirrors SquatMetricBase):
   ┌──────────┐     ┌──────────────┐     ┌──────────────┐
   │  CurlUp  │────▶│  RepContext   │◀────│  MetricBase  │
   │ (owner)  │     │ (shared state)│     │  (per metric)│
   └──────────┘     └──────────────┘     └──────────────┘

   Data flow:
   - feedback{}  → cleared every frame in checkingPose()
                  → metrics write live cards here (Range, Neck, Knee)
                  → coaching from rep evaluation or per-frame faults
                  → cleared when new rep begins (resting → ascending)

   Why curl-up has onRestingFrame:
   Unlike squat, curl-up uses PERSONAL BASELINES for two metrics (trunk
   elevation, neck pulling). The hold-still snapshot captured at activation
   provides a strong baseline, and onRestingFrame lets metrics refine it
   between reps if the user shifts position.
   ========================================================================= */

import '../curl_up.dart';
import '../../exercise_base.dart';
import '../../fault_record.dart';
import '../../../debug/debug_types.dart';
export '../../../debug/debug_types.dart';
export '../../fault_record.dart';

/* =========================================================================
   RepContext — Shared per-frame state, passed to all metrics.
   Avoids each metric needing to recalculate the same geometry.
   ========================================================================= */

class RepContext {
  /// Shoulder-hip line angle from horizontal (degrees).
  /// Lying flat = ~0°. Curling up rotates the line so this increases.
  /// World-frame measurement: sensitive to camera tilt.
  /// Provided for DEBUG/comparison with shoulderHipKneeAngle, not for
  /// primary metric thresholds.
  final double trunkAngle;

  /// Interior angle at hip: shoulder→hip→knee (degrees).
  /// Joint-frame measurement: invariant to camera tilt and hip drift.
  /// PRIMARY signal for trunk-elevation: peak elevation = baseline - min angle.
  final double shoulderHipKneeAngle;

  /// Interior angle at shoulder: ear→shoulder→hip (degrees).
  /// Rotation-invariant measure of head-vs-torso. Decreases when the user
  /// pulls their chin forward / down (cervical hyperflexion).
  final double earShoulderHipAngle;

  /// Interior angle at knee: hip→knee→ankle (degrees).
  /// Camera-side knee only (the bent knee in McGill setup). Null when the
  /// ankle is below confidence — knee-extension metric skips those frames.
  final double? hipKneeAnkleAngle;

  /// Shoulder-to-hip Euclidean distance. Used as scale factor for any
  /// metric that needs to normalize pixel distances to body size.
  final double? scaleFactor;

  final CurlUpState curlUpState;
  final int frameTimestamp; // millisecondsSinceEpoch

  /// Hold-still baselines captured during isInStartPosition. Persist for
  /// the whole set. Optional — null until activation completes.
  final double? holdStillShoulderHipKnee;
  final double? holdStillEarShoulderHip;

  // Landmark Y positions — kept for any metric that needs a y-displacement
  // signal (e.g. apex detection via shoulder.y reversal, future hip-lift
  // momentum check from spec phase 2).
  final double shoulderY;
  final double hipY;
  final double kneeY;

  /// Shared result container — metrics write feedback here.
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
    this.holdStillShoulderHipKnee,
    this.holdStillEarShoulderHip,
  });
}

/* =========================================================================
   CurlUpFaultVoicePriority — Lower number = higher voice playback priority.

   Ordering reflects spec safety ranking:
     - Neck pulling: CRITICAL (acute cervical injury)
     - Trunk too high: CRITICAL (chronic disc herniation, full sit-up territory)
     - Knee extension: IMPORTANT (chronic lumbar shear)
     - Trunk too shallow: effectiveness coaching, not a safety issue
   ========================================================================= */

class CurlUpFaultVoicePriority {
  static const int neckPulling = 0;
  static const int trunkTooHigh = 1;
  static const int kneeExtension = 2;
  static const int trunkTooShallow = 3;
}

/* =========================================================================
   CurlUpMetricBase — Interface every metric implements.
   ========================================================================= */

abstract class CurlUpMetricBase {
  /// Human-readable name for debug/logging.
  String get name;

  /// Cumulative count of reps in which this metric logged at least one fault.
  /// Set-level: incremented by resetAndCountFault() after each rep.
  int faultsCount = 0;

  /// Called every frame during an active rep (curlUpState != resting).
  /// Writes feedback directly to ctx.resultIssues.
  void update(RepContext ctx);

  /// Faults accumulated this rep. CurlUp reads these when rep completes.
  List<FaultRecord> get faults;

  /// Debug data for the overlay. Keys should be metric-specific.
  Map<String, dynamic> get debugData;

  /// Primary threshold-checked scalar shown in the debug panel.
  double? get value => null;

  /// Warning/fault bounds for developer diagnostics. The metric's own status
  /// remains the source of truth for current pass/near/fault state.
  ThresholdBand? get threshold => null;

  /// Current metric decision. Override when a metric has a primary value.
  MetricStatus get status {
    if (faults.any((fault) => fault.affectsForm)) {
      return MetricStatus.fault;
    }
    if (faults.isNotEmpty) return MetricStatus.near;
    return MetricStatus.pass;
  }

  /// Called every frame while the user is in resting state (between reps).
  /// Override in metrics that refine personal baselines from lying frames.
  /// Default: no-op.
  void onRestingFrame(RepContext ctx) {}

  /// Reset all internal state for the next rep.
  /// Persistent baselines (e.g. _baselineAngle) should NOT be cleared here.
  void reset();

  /// Called by CurlUp at rep completion. Increments faultsCount if any
  /// fault was logged this rep, then resets.
  void resetAndCountFault() {
    if (faults.isNotEmpty) {
      faultsCount++;
    }
    reset();
  }

  /// Called when curl-up state transitions (e.g. ascending → descending).
  /// Override in metrics that care about transitions (e.g. trunk elevation
  /// snapshots its peak at the apex transition).
  void onStateTransition(CurlUpState from, CurlUpState to, int timestampMs) {}
}
