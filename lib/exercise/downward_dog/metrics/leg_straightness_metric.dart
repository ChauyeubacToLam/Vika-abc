/* =========================================================================
   Check 5: Leg Straightness
   Priority: NICE-TO-HAVE — Ship Month 1-2

   Measures the knee angle: hip–knee–ankle.
   180° = straight leg.

   CRITICAL DESIGN DECISION: affectsForm = ALWAYS FALSE.
   Bent knees are explicitly blessed for Vietnamese desk workers with
   tight hamstrings. NEVER fail the hold for bent knees.
   Bent knees + long spine > straight legs + rounded back.

   Coaching fires ONLY post-hold AND only when the spine is long.
   If the spine is rounding, suppress this cue entirely — the user
   should focus on knee bend for spine length, not leg straightness.

   THRESHOLDS (ESTIMATE — pending PT review):
   ┌──────────────────────┬──────────────────────┬──────────────────────┐
   │ Week 1–4             │ Week 5–8             │ Week 9+              │
   ├──────────────────────┼──────────────────────┼──────────────────────┤
   │ Good (coaching): ≥150°│ Good: ≥ 155°         │ Good: ≥ 160°         │
   │ Bent (allowed): < 150°│ Bent: < 155°         │ Bent: < 160°         │
   └──────────────────────┴──────────────────────┴──────────────────────┘
   ========================================================================= */

import 'downward_dog_metric_base.dart';
import 'spine_round_metric.dart';

class LegStraightnessConfig {
  /// Knee angle at or above which we consider legs "straight enough".
  /// Below this is fine — surface only as a gentle post-hold nudge.
  static const double STRAIGHT_THRESHOLD = 135.0;
}

class LegStraightnessMetric extends DownwardDogMetricBase {
  @override
  String get name => 'LegStraightness';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _kneeAngle;
  double? _minKneeAngle;

  /// Track whether the spine was long throughout the hold so we decide
  /// whether to surface the leg-straightness nudge post-hold.
  bool _spineLongDuringHold = true;
  bool _isFaultingNow = false;

  // Status is always pass — this metric NEVER faults the hold.
  @override
  MetricStatus get status => MetricStatus.pass;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _kneeAngle;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningBelow: LegStraightnessConfig.STRAIGHT_THRESHOLD,
      );

  @override
  void update(HoldContext ctx) {
    _isFaultingNow = false;
    if (ctx.holdState != DownwardDogState.hold) return;

    _kneeAngle = ctx.kneeAngle;

    // Track minimum across hold for post-hold analysis.
    if (_minKneeAngle == null || ctx.kneeAngle < _minKneeAngle!) {
      _minKneeAngle = ctx.kneeAngle;
    }

    // Track spine state so we can conditionally suppress the leg nudge.
    // Suppress if spine angle drops below SpineRoundConfig.GOOD_ANGLE
    // at any point — the user needs to focus on bending knees, not legs.
    if (ctx.spineAngle < SpineRoundConfig.GOOD_ANGLE) {
      _spineLongDuringHold = false;
    }

    _debugData['kneeAngle'] = ctx.kneeAngle;
    _debugData['minKneeAngle'] = _minKneeAngle ?? 'N/A';
    _debugData['spineLongDuringHold'] = _spineLongDuringHold;

    // Live feedback: always "Gập gối nếu cần" (no fault path for this metric).
    if (ctx.kneeAngle < LegStraightnessConfig.STRAIGHT_THRESHOLD) {
      _isFaultingNow = _spineLongDuringHold;
      ctx.resultIssues.feedback['leg_straight'] =
          'Gập gối là được — giữ lưng thẳng!';
    } else {
      ctx.resultIssues.feedback['leg_straight'] = 'Chân duỗi tốt!';
    }
  }

  /// Called by DownwardDog when hold completes.
  /// Only surfaces coaching if the spine was long the whole hold.
  void evaluateHold(HoldContext ctx) {
    final double? min = _minKneeAngle;
    if (min == null) return;

    if (min < LegStraightnessConfig.STRAIGHT_THRESHOLD) {
      if (_spineLongDuringHold) {
        // Spine was great — gentle nudge toward straighter legs.
        ctx.resultIssues.addInstruction(
          'exit',
          'leg_straight',
          'Nếu gân kheo cho phép, duỗi chân thẳng hơn nhé. Còn không thì cứ gập gối.',
        );
        _logFault(
          'HOLD',
          'Legs bent — spine long (acceptable, coaching only)',
        );
      }
      // If spine was rounding, suppress: user should keep bending knees.
    }

    _debugData['postHoldResult'] = _spineLongDuringHold
        ? 'bent legs (coaching)'
        : 'spine rounding (leg cue suppressed)';
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'LegStraightness')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'LegStraightness',
        message: message,
        affectsForm: false, // NEVER fail the hold for bent knees
        voiceMessage: null,
        priority: DownwardDogFaultVoicePriority.legStraightness,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _kneeAngle = null;
    _minKneeAngle = null;
    _spineLongDuringHold = true;
    _isFaultingNow = false;
  }
}
