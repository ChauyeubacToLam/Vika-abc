// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Knee Extension (Bent Leg Stays Bent)

   Priority: 🟡 IMPORTANT (chronic lumbar shear)

   Three sub-checks during the rep:

   1. ABSOLUTE EXTENSION → fault
      ≥ 175° = ERROR (locked / nearly straight)
      165–175° = WARNING (drifting straight)

   2. BASELINE DEVIATION → live chip only, no fault
      Once activation captures a strict ~90° baseline at hold-still, any
      mid-rep drift > 15° from that baseline shows a "đưa chân về" chip.
      This nudges the user back without failing the rep — the strict
      activation gate (≤ 100° start) means the absolute thresholds will
      catch real problems anyway.

   3. ANKLE HIDDEN → silent skip
      All three sub-checks need ankle visible. When hidden, just skip.

   Landmarks: HIP (#23/#24), KNEE (#25/#26), ANKLE (#27/#28) — camera side.
   ========================================================================= */

import 'curl_up_metric_base.dart';

class KneeExtensionConfig {
  /// Knee angle at or above which the leg is locked — fault, fail rep.
  static const double ERROR_THRESHOLD = 168.0;

  /// Warning band: drifting toward straight but not yet locked.
  static const double WARNING_THRESHOLD = 155.0;

  /// Baseline-relative deviation that triggers a live nudge chip.
  /// Activation guarantees baseline is ~90° (≤ 100° max), so 15° drift
  /// means the user has crept up to ~110°. Visible signal but not a
  /// fault — they can self-correct.
  static const double DEVIATION_WARNING = 25.0;
}

/// Tracks the highest fault level reached so far this rep (absolute check).
enum _KneeFaultLevel { warning, error }

class KneeExtensionMetric extends CurlUpMetricBase {
  @override
  String get name => 'KneeExtension';
  @override
  String? get nameVi => 'Gối';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  double? _kneeAngle;
  MetricStatus _status = MetricStatus.pass;

  /// Highest fault level logged this rep (absolute check), or null.
  _KneeFaultLevel? _loggedLevel;

  /// Baseline knee angle captured at first resting frame after activation.
  /// Persists for the whole set — leg geometry doesn't change between reps.
  double? _baselineKnee;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _kneeAngle;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: KneeExtensionConfig.WARNING_THRESHOLD,
        faultAbove: KneeExtensionConfig.ERROR_THRESHOLD,
      );

  @override
  MetricStatus get status => _status;

  /// Capture the user's resting knee angle once. The strict activation
  /// gate (≤ 100°) means this baseline is guaranteed close to McGill 90°.
  @override
  void onRestingFrame(RepContext ctx) {
    if (_baselineKnee == null && ctx.hipKneeAnkleAngle != null) {
      _baselineKnee = ctx.hipKneeAnkleAngle;
      _debugData['kneeBase'] = _baselineKnee;
    }
  }

  @override
  void update(RepContext ctx) {
    final angle = ctx.hipKneeAnkleAngle;

    if (angle == null) {
      _debugData['kneeExt'] = 'ankle hidden';
      _kneeAngle = null;
      _status = MetricStatus.pass;
      return;
    }

    _kneeAngle = angle;
    _debugData['kneeExt'] = angle;

    // Order matters: absolute checks first (highest severity), then
    // deviation chip (informational), then "good."
    if (angle >= KneeExtensionConfig.ERROR_THRESHOLD) {
      _status = MetricStatus.fault;
      ctx.resultIssues.feedback['Knee'] = '🔴 Chân thẳng quá!';
      _ensureLevel(ctx, _KneeFaultLevel.error);
    } else if (angle >= KneeExtensionConfig.WARNING_THRESHOLD) {
      _status = MetricStatus.near;
      ctx.resultIssues.feedback['Knee'] = '⚠️ Co gối thêm';
      _ensureLevel(ctx, _KneeFaultLevel.warning);
    } else if (_baselineKnee != null &&
        (angle - _baselineKnee!).abs() >
            KneeExtensionConfig.DEVIATION_WARNING) {
      _status = MetricStatus.near;
      // Out of acceptable deviation band but below absolute warning band.
      // Live nudge only — no fault logged.
      ctx.resultIssues.feedback['Knee'] = '⚠️ Đưa chân về 90°';
    } else {
      _status = MetricStatus.pass;
      ctx.resultIssues.feedback['Knee'] = '✅ Gối tốt';
    }
  }

  /// Idempotent fault logger for the absolute-extension check.
  void _ensureLevel(RepContext ctx, _KneeFaultLevel level) {
    if (_loggedLevel == _KneeFaultLevel.error) return;

    final phase = ctx.curlUpState.toString().split('.').last.toUpperCase();

    if (level == _KneeFaultLevel.error) {
      _faults.removeWhere((f) => f.type == 'knee_extension');
      _faults.add(FaultRecord(
        phase: phase,
        type: 'knee_extension',
        message: 'Chân duỗi thẳng — co gối lại',
        affectsForm: true,
        voiceMessage: 'Giữ gối gập',
        priority: CurlUpFaultVoicePriority.kneeExtension,
      ));
      ctx.resultIssues.addInstruction('resting', 'Knee',
          'Rep tới giữ gối gập — chân thẳng đẩy lực vào lưng dưới.');
      _loggedLevel = _KneeFaultLevel.error;
      return;
    }

    if (_loggedLevel == null) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'knee_extension',
        message: 'Gối hơi thẳng — co thêm để giữ tư thế McGill',
        affectsForm: false,
        priority: CurlUpFaultVoicePriority.kneeExtension,
      ));
      ctx.resultIssues.addInstruction('resting', 'Knee',
          'Rep tới co gối thêm chút — đừng để chân duỗi ra.');
      _loggedLevel = _KneeFaultLevel.warning;
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _loggedLevel = null;
    _kneeAngle = null;
    _status = MetricStatus.pass;
    // _baselineKnee intentionally preserved across reps — set once
    // at first resting frame, doesn't change within a set.
  }
}
