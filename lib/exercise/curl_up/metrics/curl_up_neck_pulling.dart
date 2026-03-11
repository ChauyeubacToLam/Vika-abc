// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Neck Pulling (Cervical Hyperflexion)

   Head/neck angle relative to a personalised resting baseline — detects
   chin-to-chest pulling that stresses the cervical spine.

   Landmarks: EAR (#7/#8), SHOULDER (#11/#12), HIP (#23/#24)
   Calculation: 3-point angle at the shoulder (ear-shoulder-hip)

   When to check: Continuously during ascending and apex phases.
   Deviation > 15° from resting baseline triggers an error; > 12° a warning.
   Baseline is sampled during the first lying frames (personalised per user).
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

  /// Personalized resting baseline captured from lying state frames.
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
  void update(RepContext ctx) {
    final angle = ctx.earShoulderHipAngle;

    // Collect baseline samples during early lying frames
    if (_baselineAngle == null) {
      _baselineSum += angle;
      _baselineFrames++;
      if (_baselineFrames >= _BASELINE_SAMPLE_COUNT) {
        _baselineAngle = _baselineSum / _baselineFrames;
      }
      _debugData['neckBaseline'] = 'sampling...';
      return;
    }

    // Deviation: baseline is large (flat), angle decreases when neck flexes
    final deviation = (_baselineAngle! - angle).clamp(0.0, 90.0);

    _debugData['neckBaseline'] = _baselineAngle!.toStringAsFixed(1);
    _debugData['neckDev'] = '${deviation.toStringAsFixed(1)}°';

    // Only evaluate during concentric phase
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

  @override
  void onStateTransition(CurlUpState from, CurlUpState to, int timestampMs) {
    // Add coaching instruction when returning to lying after a neck-pull fault
    if (to == CurlUpState.resting && _faultLogged) {
      // Instructions will be attached by the fault system
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
    // Keep baseline — it's personalized and doesn't change between reps.
  }
}
