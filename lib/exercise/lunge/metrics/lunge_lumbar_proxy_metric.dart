/* =========================================================================
   Lunge Metric: Lumbar Proxy

   Detects lower-back arching (anterior pelvic tilt) using the
   Shoulder-Hip-TrailingKnee angle as a proxy for lumbar extension.

   Landmarks: SHOULDER (#11/#12), HIP (#23/#24), trailing KNEE (#25/#26)
   Calculation: 3-point angle at hip (shoulder-hip-trailingKnee)

   Trigger condition: ONLY flag as error when BOTH:
     (1) Shoulder-Hip-TrailingKnee angle < 140°
     AND
     (2) trunk lean < 10° (torso nearly vertical)
   If the user is leaning forward naturally, the acute angle is expected
   and not a fault.

   When to check: Bottom phase only (maximum lumbar stress).
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
      // < 140° with upright torso — lower back arching
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
      // 140° – 159° — warning zone (feedback only, no fault)
      ctx.resultIssues.feedback['Core'] = 'Siết cơ bụng, giữ thẳng hàng';
    } else {
      // ≥ 160° — good alignment
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
