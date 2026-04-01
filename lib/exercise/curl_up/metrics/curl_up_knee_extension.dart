// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Knee Extension (Bent Leg Stays Bent)

   Interior angle of the camera-side bent knee — detects if the user
   accidentally straightens it during the curl (losing the McGill
   lumbar-neutral setup). Straight/locked knees shift force to the
   lower back and increase lumbar shear.

   Landmarks: HIP, KNEE, ANKLE (camera-side only)
   Calculation: calculateAngleNormalized(Hip, Knee, Ankle)

   When to check: Continuously throughout the rep.
   Ankle is optional — metric silently skips frames where ankle
   is not visible or below confidence threshold.

   ≥ 150° = locked (error), ≥ 140° = drifting straight (warning).
   Tighter than typical thresholds because McGill setup starts at ~90°;
   drift to 140° already compromises lumbar neutral.
   ========================================================================= */

import 'curl_up_metric_base.dart';

class KneeExtensionConfig {
  /// Knee angle above which legs are considered locked/extended.
  static const double LOCKED_THRESHOLD = 150.0;

  /// Warning zone: bent knee drifting too straight.
  static const double WARNING_THRESHOLD = 140.0;
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

    if (kneeAngle == null) {
      // Ankle not visible — can't assess knee extension this frame.
      return;
    }

    _debugData['kneeExt'] = '${kneeAngle.toStringAsFixed(1)}°';

    if (kneeAngle >= KneeExtensionConfig.LOCKED_THRESHOLD) {
      ctx.resultIssues.feedback['Knee'] = '🔴 Chân thẳng quá!';
      if (!_faultLogged) {
        _logFault(
          ctx.curlUpState.toString().split('.').last.toUpperCase(),
          'Chân duỗi thẳng — co gối lại!',
          voiceMessage: 'Giữ gối gập',
        );
        _faultLogged = true;
      }
    } else if (kneeAngle >= KneeExtensionConfig.WARNING_THRESHOLD) {
      ctx.resultIssues.feedback['Knee'] = '⚠️ Co gối thêm';
    } else {
      ctx.resultIssues.feedback['Knee'] = '✅ Gối tốt';
    }
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Knee')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Knee',
        message: message,
        voiceMessage: voiceMessage,
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
