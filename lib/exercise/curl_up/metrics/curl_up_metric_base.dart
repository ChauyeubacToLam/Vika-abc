/* =========================================================================
   CurlUpMetricBase — Abstract base for all curl-up form metrics.

   Architecture mirrors SquatMetricBase:
   ┌──────────┐     ┌──────────────┐     ┌──────────────┐
   │  CurlUp  │────▶│  RepContext   │◀────│  MetricBase  │
   │  (owner) │     │ (shared state)│     │  (per metric)│
   └──────────┘     └──────────────┘     └──────────────┘
   ========================================================================= */

import '../curl_up.dart';
import '../../exercise_base.dart';

/* =========================================================================
   RepContext — Shared per-frame state, passed to all metrics.
   ========================================================================= */
class RepContext {
  final double trunkAngle; // Degrees from horizontal (0 = flat, + = curling up)
  final double
      shoulderHipKneeAngle; // Interior angle at hip (Shoulder-Hip-Knee)
  final double
      earShoulderHipAngle; // Interior angle at shoulder (Ear-Shoulder-Hip)
  final double hipKneeAnkleAngle; // Interior angle at knee (Hip-Knee-Ankle)
  final double? scaleFactor;
  final CurlUpState curlUpState;
  final int frameTimestamp; // millisecondsSinceEpoch

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
  });
}

/* =========================================================================
   FaultRecord — A single fault logged by a metric.
   ========================================================================= */
class FaultRecord {
  final String phase;
  final String type;
  final String message;
  final bool affectsForm;

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
  String get name;

  void update(RepContext ctx);

  List<FaultRecord> get faults;

  Map<String, dynamic> get debugData;

  void reset();

  void onStateTransition(CurlUpState from, CurlUpState to, int timestampMs) {}
}
