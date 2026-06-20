// ignore_for_file: constant_identifier_names, non_constant_identifier_names, annotate_overrides

/* =========================================================================
   WarriorOneMetricBase — Abstract base for all Warrior I form metrics.

   Mirrors PlankMetricBase (hold pattern) + LungeMetricBase (metric pattern).

   ┌─────────────┐     ┌──────────────┐     ┌──────────────────────┐
   │  WarriorOne │────▶│  HoldContext  │◀────│  WarriorOneMetricBase│
   │   (owner)   │     │ (shared state)│     │     (per metric)     │
   └─────────────┘     └──────────────┘     └──────────────────────┘

   Warrior I is a STATIC HOLD (ENTRY → HOLD → EXIT), so there is no
   "rep". Metrics evaluate every frame during HOLD only and accumulate
   FaultRecords; WarriorOne reads them when the hold completes.
   ========================================================================= */

import '../warrior_one.dart';
import '../../exercise_base.dart'; // ResultIssues
import '../../fault_record.dart';
export '../../fault_record.dart';

/* =========================================================================
   HoldContext — Shared per-frame geometry, passed to every metric.
   WarriorOne computes this once per frame so metrics don't recompute it.
   All angles are in degrees. trunkLean is signed (positive = forward).
   ========================================================================= */
class HoldContext {
  /// Signed torso lean from vertical. Positive = leaning forward, 0 = upright.
  final double trunkLean;

  /// Ear–Shoulder–Hip angle. 180° = head in line with trunk. Lower = thrown back.
  /// Raw (only globally smoothed). The cervical metric does its own extra
  /// filtering (1D One-Euro + rolling median) on this value.
  final double cervicalAngle;

  /// Angle of the wrist→shoulder line from vertical (arm "overhead-ness").
  /// 0° = straight overhead. Larger = arms hanging forward.
  final double armVerticalAngle;

  /// Shoulder–Elbow–Wrist angle. 180° = straight elbow. Lower = bent.
  final double elbowAngle;

  /// Back-leg Hip–Knee–Ankle angle. 180° = straight. Lower = bent/floppy.
  final double backKneeAngle;

  /// False when the wrist has left the top of the frame (low ceiling).
  /// Used to disable the elbow sub-check, which is meaningless if the
  /// wrist isn't visible.
  final bool wristVisible;

  final WarriorOneState holdState;
  final int frameTimestamp; // frameTimestampMs

  /// Torso length (shoulder→hip) used to normalize distance metrics.
  final double scaleFactor;
  final double spineAngle;

  /// Personal references captured during hold-still (ENTRY → HOLD).
  /// May be null on the very first frames before capture.
  final double? trunkBaseline; // shoulder-hip vertical angle at hold-still
  final double? cervicalBaseline; // ear-shoulder-hip angle at hold-still

  /// Shared result container — metrics write feedback + instructions here.
  final ResultIssues resultIssues;

  HoldContext({
    required this.trunkLean,
    required this.cervicalAngle,
    required this.armVerticalAngle,
    required this.elbowAngle,
    required this.backKneeAngle,
    required this.wristVisible,
    required this.holdState,
    required this.frameTimestamp,
    required this.scaleFactor,
    required this.trunkBaseline,
    required this.cervicalBaseline,
    required this.resultIssues,
    required this.spineAngle,
  });
}

/* =========================================================================
   WarriorOneMetricBase — Interface every Warrior I metric implements.
   ========================================================================= */
abstract class WarriorOneMetricBase with FaultMetricDebugSource {
  int faultsCount = 0;

  /// Human-readable name for debug/logging.
  String get name;

  /// Called every frame during an active hold (holdState == hold).
  /// Writes live feedback + post-hold instructions to ctx.resultIssues.
  void update(HoldContext ctx);

  /// Faults accumulated this hold. WarriorOne reads these at hold completion.
  List<FaultRecord> get faults;
  bool get isFaultingNow => false;

  /// Debug data for the overlay. Keys should be metric-specific.
  Map<String, dynamic> get debugData;

  /// Reset all internal state for the next hold (e.g. the other side).
  void reset();

  void resetAndCountFault() {
    if (faults.isNotEmpty) faultsCount++;
    reset();
  }

  /// Called when the hold state transitions (entry → hold → exit).
  /// Override in metrics that care about transitions.
  void onStateTransition(
      WarriorOneState from, WarriorOneState to, int timestampMs) {}
}
