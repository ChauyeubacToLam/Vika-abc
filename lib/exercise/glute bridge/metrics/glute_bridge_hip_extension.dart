/* =========================================================================
   Metric 1.1: Hip Extension Alignment (Hyperextension Detector)
   Priority: 🔴 CRITICAL (acute injury risk)

   Two-directional detection:
     (1) Insufficient hip extension / sagging hips → ineffective rep
     (2) Hyperextension past neutral (lumbar arching) → #1 injury risk

   Landmarks: Camera-side SHOULDER, HIP, KNEE via getSideLandmark().

   Calculation:
     Primary:  calculateAngle(SHOULDER, HIP, KNEE) — internal angle at hip.
               A straight shoulder-to-knee line at top ≈ 170–180°.
     Deviation: Perpendicular distance from HIP to SHOULDER-KNEE line,
               normalized by SHOULDER-KNEE segment length.
               Positive = hip above line (hyperextension).
               Negative = hip below line (sagging).

   Threshold Table — Vietnamese-adjusted:
     Good         : 152–175°
     Warning      : 140–152°  (affectsForm = false)
     Error (low)  : < 140°    (affectsForm = true)
     Error (hyper): deviation > 0.045 (affectsForm = true)

   When to check:
     - Per-rep at TOP_HOLD (peak angle snapshot passed in checkRepCompletion).
     - Continuous monitoring for hyperextension during late ascending and topHold.
   ========================================================================= */

import 'glute_bridge_metric_base.dart';
import '../glute_bridge.dart';
import '../../../../utils/debouncer.dart';

class HipExtensionConfig {
  // Shoulder-hip-knee angle thresholds (Vietnamese adjusted)
  static const double GOOD_MIN_ANGLE = 152.0;
  static const double WARNING_MIN_ANGLE = 140.0;
  // Below WARNING_MIN_ANGLE → affectsForm = true (error)
  // Between WARNING_MIN_ANGLE and GOOD_MIN_ANGLE → affectsForm = false (warning)

  // Normalized perpendicular deviation from the shoulder-knee line.
  // Positive = hip above the line = lumbar hyperextension risk.
  static const double HYPEREXT_THRESHOLD = 0.045;

  // Require this many consecutive frames before flagging live hyperextension.
  static const int HYPEREXT_DEBOUNCE_FRAMES = 6;
}

class HipExtensionMetric extends GluteBridgeMetricBase {
  @override
  String get name => 'HipExtension';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Debouncer for continuous hyperextension detection.
  final Debouncer _hyperextDebouncer =
      Debouncer(requiredFrames: HipExtensionConfig.HYPEREXT_DEBOUNCE_FRAMES);

  // Prevent duplicate fault within one rep.
  bool _hyperextFaultAdded = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /* -----------------------------------------------------------------------
     Per-frame update — continuous hyperextension monitoring.
     Only active during ascending and topHold states (late concentric onset).
     ----------------------------------------------------------------------- */
  @override
  void update(RepContext ctx) {
    _debugData['hipAngle'] = ctx.shoulderHipKneeAngle.toStringAsFixed(1);
    _debugData['hipDev'] =
        '${ctx.normalizedHipDeviation >= 0 ? "+" : ""}${ctx.normalizedHipDeviation.toStringAsFixed(3)}';

    if (ctx.state != GluteBridgeState.ascending &&
        ctx.state != GluteBridgeState.topHold) {
      return;
    }

    final bool isHyperextending =
        ctx.normalizedHipDeviation > HipExtensionConfig.HYPEREXT_THRESHOLD;

    if (_hyperextDebouncer.update(isHyperextending)) {
      // Fault — recorded once per rep.
      if (!_hyperextFaultAdded) {
        _faults.add(FaultRecord(
          phase: ctx.state.toString().split('.').last,
          type: 'hyperextension',
          message: 'Không ưỡn lưng — ép lưng vào sàn',
          affectsForm: true,
        ));
        _hyperextFaultAdded = true;
      }
    }
  }

  /* -----------------------------------------------------------------------
     Per-rep evaluation — called at TOP_HOLD → DESCENDING transition.

     peakAngle    : shoulderHipKneeAngle at the highest hip point this rep.
     peakDeviation: normalizedHipDeviation at that same peak frame.
     ----------------------------------------------------------------------- */
  void checkRepCompletion(double? peakAngle, double? peakDeviation) {
    if (peakAngle == null) return;

    _debugData['peakAngle'] = '${peakAngle.toStringAsFixed(1)}°';
    if (peakDeviation != null) {
      _debugData['peakDev'] =
          '${peakDeviation >= 0 ? "+" : ""}${peakDeviation.toStringAsFixed(3)}';
    }

    // --- Hyperextension check (angle-based, per-rep snapshot) ---
    // Complements the continuous debouncer above. Catches cases where the
    // debouncer fires mid-ascent but the true peak was borderline.
    if (peakDeviation != null &&
        peakDeviation > HipExtensionConfig.HYPEREXT_THRESHOLD &&
        !_hyperextFaultAdded) {
      _faults.add(FaultRecord(
        phase: 'topHold',
        type: 'hyperextension',
        message: 'Không ưỡn lưng — ép lưng vào sàn',
        affectsForm: true,
      ));
    }

    // --- Insufficient extension / sagging hips ---
    if (peakAngle < HipExtensionConfig.GOOD_MIN_ANGLE) {
      final bool isError = peakAngle < HipExtensionConfig.WARNING_MIN_ANGLE;
      _faults.add(FaultRecord(
        phase: 'topHold',
        type: 'hip_extension',
        message: isError
            ? 'Nâng hông cao hơn — co mông tối đa'
            : 'Cố gắng nâng hông thêm một chút',
        voiceMessage: 'Nâng hông cao hơn',
        affectsForm: isError, // error if < 140°, warning if 140–152°
      ));
    }
  }

  /* -----------------------------------------------------------------------
     State transition hook — reset debouncer when a new rep begins.
     ----------------------------------------------------------------------- */
  @override
  void onStateTransition(
      GluteBridgeState from, GluteBridgeState to, int timestampMs) {
    if (to == GluteBridgeState.ascending || to == GluteBridgeState.bottom) {
      _hyperextDebouncer.reset();
      _hyperextFaultAdded = false;
    }
  }

  @override
  void reset() {
    _faults.clear();
    _hyperextDebouncer.reset();
    _hyperextFaultAdded = false;
  }
}
