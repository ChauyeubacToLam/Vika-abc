/* =========================================================================
   Lunge Metric: Lumbar Hyperextension Proxy

   Proxy approach: Measure Shoulder-Hip-Trailing_Knee angle. In a safe lunge,
   torso and trailing thigh form a roughly straight line at bottom (~160°–180°).
   If this angle becomes acute (<140°) while torso remains vertical (<10° lean),
   the pelvis is anteriorly tilted → lumbar hyperextension risk.

   Landmarks: SHOULDER (#11/#12), HIP (#23/#24), TRAILING_KNEE (#25/#26)
   Calculation: calculateAngle(Shoulder, Hip, TrailingKnee)

   When to check: Bottom phase only (15-frame window ~500ms)
   Debounce: 5 frames (~167ms)
   Estimated catch rate: ~65% of severe hyperextension cases
   False positive risk: LOW — a highly acute angle at this junction almost
                        always signifies improper pelvic mechanics.

   Trigger condition: ONLY flag as error when BOTH:
     (1) Shoulder-Hip-TrailingKnee angle < 140°
     AND
     (2) trunk lean < 10° (torso nearly vertical)
   If the user is leaning forward naturally, the acute angle is expected
   and not a fault.

   Thresholds:
     ✅  ≥ 160°              → Good alignment
     ⚠️  140° – 159°         → Brace your core, stay aligned
     ❌  < 140° (+ upright)  → Lower back arching! Brace core!

   Feedback framing: "Giữ ngực, hông và đầu gối sau thẳng hàng như một
   đường thẳng" (Keep your chest, back hip, and back knee in a straight,
   strong line.)
   ========================================================================= */

import 'lunge_metric_base.dart';
import '../lunge.dart';
import '../../../utils/debouncer.dart';

class LungeLumbarProxyConfig {
  /// Good alignment: angle ≥ 160°
  static const double GOOD_THRESHOLD = 160.0;

  /// Warning zone: 140° – 159°
  static const double WARN_THRESHOLD = 140.0;

  /// Trunk lean must be below this (degrees) for the fault to trigger.
  /// If the user is leaning forward naturally, the acute angle is expected.
  static const double UPRIGHT_TORSO_LIMIT = 10.0;
}

class LungeLumbarProxyMetric extends LungeMetricBase {
  @override
  String get name => 'LumbarProxy';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // 5 frames (~167ms) debounce
  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 5);

  /// Prevent instruction spam — only set coaching once per rep.
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LungeRepContext ctx) {
    // Only check during bottom phase
    if (ctx.lungeState != LungeState.bottom) {
      return;
    }

    final double shAngle = ctx.shoulderHipTrailKneeAngle;
    final double trunkLean = ctx.trunkLean;

    _debugData['shTrailKneeAngle'] = shAngle.toStringAsFixed(1);
    _debugData['lumbarTrunkLean'] = trunkLean.toStringAsFixed(1);

    final String phase =
        ctx.lungeState.toString().split('.').last.toUpperCase();

    // Combined trigger: acute angle AND upright torso
    final bool isBad = shAngle < LungeLumbarProxyConfig.WARN_THRESHOLD &&
        trunkLean < LungeLumbarProxyConfig.UPRIGHT_TORSO_LIMIT;

    if (_faultDebouncer.update(isBad)) {
      // ❌ < 140° with upright torso — lower back arching
      ctx.resultIssues.feedback['Core'] = 'Lưng đang võng! Gồng cơ bụng!';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          'standing',
          'Core',
          'Giữ ngực, hông và đầu gối sau thẳng hàng như một đường thẳng.',
        );
        _instructionSet = true;
      }
      _logFault(phase, 'Lower back arching! Brace core!');
    } else if (shAngle >= LungeLumbarProxyConfig.WARN_THRESHOLD &&
        shAngle < LungeLumbarProxyConfig.GOOD_THRESHOLD) {
      // ⚠️ 140° – 159° — warning zone (feedback only, no fault)
      ctx.resultIssues.feedback['Core'] = 'Siết cơ bụng, giữ thẳng hàng';
    } else {
      // ✅ ≥ 160° — good alignment
      ctx.resultIssues.feedback['Core'] = 'Tư thế tốt';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Core')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Core',
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _faultDebouncer.reset();
    _instructionSet = false;
  }
}
