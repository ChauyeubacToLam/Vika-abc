/* =========================================================================
   GluteBridgeMetricBase — Abstract base for all glute-bridge form metrics.

   Architecture mirrors PushUpMetricBase:
   ┌─────────────┐     ┌──────────────┐     ┌──────────────────────┐
   │ GluteBridge │────▶│  RepContext   │◀────│ GluteBridgeMetricBase│
   │  (owner)    │     │ (shared state)│     │    (per metric)      │
   └─────────────┘     └──────────────┘     └──────────────────────┘

   Primary signal: HIP y-coordinate and its velocity (pixels/frame).
   In screen coordinates y increases downward, so:
     hip RISING  → velocity is NEGATIVE
     hip FALLING → velocity is POSITIVE
   ========================================================================= */

import '../glute_bridge.dart';
import '../../exercise_base.dart';
import '../../fault_record.dart';
export '../../fault_record.dart';
/* =========================================================================
   RepContext — Shared per-frame state passed to all metrics.
   ========================================================================= */
class RepContext {
  /// Hip y-coordinate in screen pixels.
  final double hipY;

  /// Shoulder y-coordinate (should stay roughly constant during the exercise).
  final double shoulderY;

  /// Smoothed hip y velocity (pixels/frame).
  /// Negative = hip rising, Positive = hip falling.
  final double hipVelocity;

  /// Angle at the hip between shoulder→hip and hip→knee vectors (degrees).
  /// ~165-175° when flat; ~120-135° when bridged.
  final double shoulderHipKneeAngle;

  /// Perpendicular distance from HIP to the SHOULDER-KNEE line,
  /// normalized by the SHOULDER-KNEE segment length.
  ///   Positive = hip above the shoulder-knee line → lumbar hyperextension risk.
  ///   Negative = hip below the line → sagging / insufficient extension.
  ///   ≈ 0 when hip lies exactly on the line (ideal neutral bridge).
  final double normalizedHipDeviation;

  /// Internal angle at the knee: HIP-KNEE-ANKLE (degrees).
  /// Null if the ankle landmark is not available or below confidence.
  final double? kneeAngle;

  /// Shoulder-to-hip distance in pixels (body size normalisation).
  final double? scaleFactor;

  /// Camera-side EAR y-coordinate (or NOSE fallback) in screen pixels.
  /// Null if no head landmark meets the confidence threshold.
  final double? headY;

  final GluteBridgeState state;
  final int frameTimestamp; // millisecondsSinceEpoch

  /// Hip y at the calibrated bottom position (captured during hold-still).
  final double baselineHipY;

  /// Shared result container — metrics write feedback + instructions here.
  final ResultIssues resultIssues;

  const RepContext({
    required this.hipY,
    required this.shoulderY,
    required this.hipVelocity,
    required this.shoulderHipKneeAngle,
    required this.normalizedHipDeviation,
    required this.kneeAngle,
    required this.scaleFactor,
    required this.headY,
    required this.state,
    required this.frameTimestamp,
    required this.baselineHipY,
    required this.resultIssues,
  });
}


/* =========================================================================
   GluteBridgeMetricBase — Interface every glute-bridge metric implements.
   ========================================================================= */
abstract class GluteBridgeMetricBase {
  String get name;

  /// Called every frame while state == bottom (setup coaching).
  void onBottomFrame(RepContext ctx) {}

  /// Called every frame while state != bottom.
  void update(RepContext ctx);

  /// Faults accumulated this rep. Inspected at rep completion.
  List<FaultRecord> get faults;

  /// Debug key-value pairs for the overlay panel.
  Map<String, dynamic> get debugData;

  /// Reset all internal state for the next rep.
  void reset();

  /// Called on every glute-bridge state transition.
  void onStateTransition(
      GluteBridgeState from, GluteBridgeState to, int timestampMs) {}
}
