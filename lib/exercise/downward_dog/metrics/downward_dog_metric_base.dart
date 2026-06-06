/* =========================================================================
   DownwardDogMetricBase — Abstract base for all Downward Dog hold metrics.

   Each metric is a self-contained unit that:
   - Receives frame data via update()
   - Writes feedback + instructions to ctx.resultIssues
   - Logs faults into its own fault list
   - Resets cleanly between holds

   Architecture:
   ┌──────────────┐     ┌──────────────┐     ┌──────────────────────┐
   │ DownwardDog  │────▶│  HoldContext  │◀────│ DownwardDogMetricBase│
   │   (owner)    │     │ (shared state)│     │     (per metric)     │
   └──────────────┘     └──────────────┘     └──────────────────────┘

   Data flow:
   - feedback{}  → cleared every frame in processFrame()
                  → metrics write live cards here (Spine, Shoulder, Leg, etc.)
   - instructions{phase → {type → message}}
                  → coaching from evaluateHold() or per-frame faults
                  → cleared when new hold begins (ENTRY → HOLD)
                  → UI reads instructions[currentPhase] for coaching chips

   Pattern mirrors warrior_one_metric_base.dart (hold-based state machine).
   ========================================================================= */

import '../downward_dog.dart';
import 'package:vika/exercise/exercise_base.dart';
export '../../../debug/debug_types.dart';
export '../../fault_record.dart';
export '../downward_dog.dart';

/* =========================================================================
   HoldContext — Shared per-frame state, passed to all metrics.
   Avoids each metric needing to recalculate the same geometry.
   ========================================================================= */

class HoldContext {
  /// Angle at the shoulder: wrist–shoulder–hip (degrees).
  /// ~165–180° = arms and torso in one long line.
  final double spineAngle;

  /// Angle at the hip: shoulder–hip–ankle (degrees).
  /// Smaller = deeper V (more acute apex).
  final double apexAngle;

  /// Angle at the knee: hip–knee–ankle (degrees).
  /// 180° = straight leg.
  final double kneeAngle;

  /// Normalized vertical distance: (ear.y – shoulder.y) / scaleFactor.
  /// Positive = ear above shoulder (good). Near-zero = shrug.
  final double earShoulderDist;

  /// Shoulder-to-hip pixel distance; used to normalise distances.
  final double? scaleFactor;

  /// Personal spine baseline captured at hold-still (wrist-shoulder-hip angle).
  final double? spineBaseline;

  /// Personal ear-shoulder distance baseline captured at hold-still.
  final double? earShoulderBaseline;

  /// Personal V-apex baseline captured at hold-still (shoulder-hip-ankle angle).
  final double? apexBaseline;

  /// Current state of the exercise.
  final DownwardDogState holdState;

  /// Frame timestamp (millisecondsSinceEpoch).
  final int frameTimestamp;

  /// Shared result container — metrics write feedback + instructions here.
  final ResultIssues resultIssues;

  HoldContext({
    required this.spineAngle,
    required this.apexAngle,
    required this.kneeAngle,
    required this.earShoulderDist,
    required this.scaleFactor,
    required this.spineBaseline,
    required this.earShoulderBaseline,
    required this.apexBaseline,
    required this.holdState,
    required this.frameTimestamp,
    required this.resultIssues,
  });
}

/* =========================================================================
   DownwardDogFaultVoicePriority — Lower = more important for post-hold playback.
   ========================================================================= */
class DownwardDogFaultVoicePriority {
  static const int spineRound = 0;
  static const int shoulderShrug = 1;
  static const int hipHeight = 2;
  static const int legStraightness = 3;
}

/* =========================================================================
   DownwardDogMetricBase — Interface every metric implements.
   ========================================================================= */
abstract class DownwardDogMetricBase implements DebugMetricSource {
  /// Human-readable name for debug / logging.
  @override
  String get name;

  /// Fault counter across holds.
  int faultsCount = 0;

  /// Called every frame during HOLD state.
  /// Writes feedback + instructions directly to ctx.resultIssues.
  void update(HoldContext ctx);

  /// Faults accumulated this hold. DownwardDog reads these when hold ends.
  List<FaultRecord> get faults;

  /// Debug data for the overlay. Keys should be metric-specific.
  @override
  Map<String, dynamic> get debugData;

  /// Primary threshold-checked scalar shown in the debug panel.
  @override
  double? get value => null;

  /// Warning/fault bounds for debug sparklines.
  @override
  ThresholdBand? get threshold => null;

  /// Current metric decision.
  @override
  MetricStatus get status => MetricStatus.pass;

  /// Friendly Vietnamese label for user-facing debug mode.
  @override
  String? get nameVi => null;

  /// Hide highly technical metrics from user-facing debug mode.
  @override
  bool get devOnly => false;

  /// Reset all internal state for the next hold.
  void reset();

  /// Reset and increment fault counter if this hold had faults.
  void resetAndCountFault() {
    if (faults.isNotEmpty) {
      faultsCount++;
    }
    reset();
  }

  /// Called when exercise state transitions (ENTRY → HOLD → EXIT).
  /// Override in metrics that need transition timestamps.
  void onStateTransition(
      DownwardDogState from, DownwardDogState to, int timestampMs) {}
}
