// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Neck Pulling (Cervical Hyperflexion)

   Head/neck angle relative to a personalized resting baseline — detects
   chin-to-chest pulling that stresses the cervical spine.

   Landmarks: EAR (#7/#8), SHOULDER (#11/#12), HIP (#23/#24)
   Calculation: 3-point angle at the shoulder (ear-shoulder-hip)

   Baseline source priority:
   1. Hold-still activation (3s motionless, captured in isInStartPosition)
   2. Resting frame averaging (accumulated between reps)
   Baseline persists across reps — head posture doesn't change mid-set.

   When to check: Continuously during ascending and apex phases.
   Deviation > 15° from resting baseline triggers an error; > 12° a warning.
   Vietnamese adjustment: personalized baseline accounts for pre-existing
   thoracic kyphosis common in desk workers.
   ========================================================================= */

import 'curl_up_metric_base.dart';
import '../curl_up.dart';

class NeckPullingConfig {
  /// Deviation from personal baseline that triggers a warning.
  static const double WARNING_DEVIATION = 12.0;

  /// Deviation from personal baseline that triggers an error.
  static const double ERROR_DEVIATION = 15.0;
}

class NeckPullingMetric extends CurlUpMetricBase {
  @override
  String get name => 'NeckPulling';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Personalized resting baseline. Set from hold-still or resting frames.
  /// Persists across reps — never cleared by reset().
  double? _baselineAngle;
  int _baselineFrames = 0;
  double _baselineSum = 0.0;
  static const int _BASELINE_SAMPLE_COUNT = 5;

  /// Whether a neck-pull fault was already logged this rep.
  bool _faultLogged = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onRestingFrame(RepContext ctx) {
    // Use hold-still baseline as primary if we don't have one yet.
    // 3 seconds of guaranteed stillness beats any averaging window.
    if (_baselineAngle == null && ctx.holdStillEarShoulderHip != null) {
      _baselineAngle = ctx.holdStillEarShoulderHip;
      _debugData['neckBaseline'] =
          '${_baselineAngle!.toStringAsFixed(1)} (hold)';
      return;
    }

    // Refine with resting frame averaging.
    final angle = ctx.earShoulderHipAngle;
    _baselineSum += angle;
    _baselineFrames++;
    if (_baselineFrames >= _BASELINE_SAMPLE_COUNT) {
      _baselineAngle = _baselineSum / _baselineFrames;
      _debugData['neckBaseline'] = _baselineAngle!.toStringAsFixed(1);
    } else {
      _debugData['neckBaseline'] = 'sampling...';
    }
  }

  @override
  void update(RepContext ctx) {
    final angle = ctx.earShoulderHipAngle;

    if (_baselineAngle == null) {
      _debugData['neckBaseline'] = 'no baseline';
      return;
    }

    // Deviation: baseline is large (flat), angle decreases when neck flexes.
    final deviation = (_baselineAngle! - angle).clamp(0.0, 90.0);

    _debugData['neckBaseline'] = _baselineAngle!.toStringAsFixed(1);
    _debugData['neckDev'] = '${deviation.toStringAsFixed(1)}°';

    // Only evaluate during concentric phase.
    if (ctx.curlUpState != CurlUpState.ascending &&
        ctx.curlUpState != CurlUpState.apex) {
      return;
    }

    if (deviation >= NeckPullingConfig.ERROR_DEVIATION) {
      ctx.resultIssues.feedback['Neck'] = '🔴 Đừng kéo cổ!';
      if (!_faultLogged) {
        _logFault(
          ctx.curlUpState.toString().split('.').last.toUpperCase(),
          'Kéo cổ quá mạnh — giữ đầu trung tính!',
        );
        _faultLogged = true;
      }
    } else if (deviation >= NeckPullingConfig.WARNING_DEVIATION) {
      ctx.resultIssues.feedback['Neck'] = '⚠️ Giữ cổ thẳng';
    } else {
      ctx.resultIssues.feedback['Neck'] = '✅ Cổ tốt';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Neck')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Neck',
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _faultLogged = false;
    // Baseline persists across reps — head posture doesn't change mid-set.
    // _baselineAngle, _baselineSum, _baselineFrames intentionally kept.
  }
}
