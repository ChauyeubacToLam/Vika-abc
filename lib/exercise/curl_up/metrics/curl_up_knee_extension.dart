// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Knee Extension (Locked Legs)

   Interior knee angle — whether the legs remain bent during the curl.
   Straight/locked knees shift force to the lower back and increase
   lumbar shear.

   Landmarks: HIP (#23/#24), KNEE (#25/#26), ANKLE (#27/#28)
   Calculation: 3-point angle at the knee (hip-knee-ankle)

   When to check: Continuously throughout the rep.
   ≥ 175° = locked (error), ≥ 170° = getting straight (warning).
   ========================================================================= */

import 'curl_up_metric_base.dart';

class KneeExtensionConfig {
  /// Knee angle above which legs are considered locked/extended.
  static const double LOCKED_THRESHOLD = 175.0;

  /// Warning zone: legs getting too straight.
  static const double WARNING_THRESHOLD = 170.0;
}

class KneeExtensionMetric extends CurlUpMetricBase {
  @override
  String get name => 'KneeExtension';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Whether a locked-knee fault was already logged this rep.
  bool _faultLogged = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    final kneeAngle = ctx.hipKneeAnkleAngle;

    _debugData['kneeExt'] = '${kneeAngle.toStringAsFixed(1)}°';

    if (kneeAngle >= KneeExtensionConfig.LOCKED_THRESHOLD) {
      ctx.resultIssues.feedback['Knee'] = '🔴 Chân thẳng quá!';
      if (!_faultLogged) {
        _logFault(
          ctx.curlUpState.toString().split('.').last.toUpperCase(),
          'Chân duỗi thẳng — co gối lại!',
        );
        _faultLogged = true;
      }
    } else if (kneeAngle >= KneeExtensionConfig.WARNING_THRESHOLD) {
      ctx.resultIssues.feedback['Knee'] = '⚠️ Co gối thêm';
    } else {
      ctx.resultIssues.feedback['Knee'] = '✅ Gối tốt';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Knee')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Knee',
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
  }
}
