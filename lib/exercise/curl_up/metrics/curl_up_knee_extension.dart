// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Metric 3: Knee Extension Angle (Locked Legs)
   Priority: IMPORTANT — Chronic back stress.

   Measures: calculateAngle(Hip, Knee, Ankle) — the interior knee angle.

   Locked/straight knees shift force to the lower back, increasing
   rectus femoris activity, anterior pelvic tilt, and shear/compression
   at the lumbar spine.

   Threshold: ~170° (extended/locked), with slight leniency to 175°
   for Vietnamese demographic due to proportionally longer legs.
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
