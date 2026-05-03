// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Knee Extension (Bent Leg Stays Bent)

   Priority: 🟡 IMPORTANT (chronic lumbar shear)

   What it measures:
   Interior angle of the camera-side bent knee. Detects when the user
   accidentally straightens it during the set, losing the McGill
   lumbar-neutral setup. Locked knees increase rectus femoris activity,
   which pulls the pelvis into anterior tilt and increases shear/compression
   at the lumbar spine — the exact load the curl-up is supposed to avoid.

   Landmarks: HIP (#23/#24), KNEE (#25/#26), ANKLE (#27/#28) — camera side.
   Calculation: Interior angle at knee — calculateAngle(Hip, Knee, Ankle).
                Joint-frame measurement; absolute (no baseline needed).
                A locked-out leg approaches 180°.

   Ankle visibility:
   Ankle is OPTIONAL in the landmark bundle (small Vietnamese apartments
   often crop the ankle out of frame). When `hipKneeAnkleAngle` is null,
   this metric silently skips the frame. Worst case is a false negative —
   acceptable since this is the lowest-priority safety metric and the user
   can usually self-correct via the live "Gối tốt" feedback when ankle IS
   visible.

   Threshold table (per VinaFit spec, Vietnamese-leniency adjusted):
     ≥ 175°: ERROR    — locked / nearly-straight (affectsForm=true)
     165–175°: WARNING — drifting straight, coach toward bend (affectsForm=false)
     < 165°: GOOD     — bent leg holding McGill setup

   Why 175° error (not 170°):
   The spec lists ~170° as the literature threshold but explicitly notes
   "Allow slight leniency (e.g., 175°) for the Vietnamese demographic due
   to proportionally longer legs." Going with 175° prevents flagging users
   whose longer lower legs naturally produce slightly more open knee angles
   when the foot is positioned for comfortable McGill setup.

   Evaluation timing:
   Continuous during ascending AND descending. update() logs the fault the
   moment threshold crosses; upgrades from warning → error in-place if the
   leg keeps straightening. No checkRepCompletion — knee position is
   knowable every frame ankle is visible.
   ========================================================================= */

import 'curl_up_metric_base.dart';

class KneeExtensionConfig {
  /// Knee angle at or above which the leg is locked — fault, fail rep.
  static const double ERROR_THRESHOLD = 175.0;

  /// Warning band: drifting toward straight but not yet locked.
  static const double WARNING_THRESHOLD = 165.0;
}

/// Tracks the highest fault level reached so far this rep.
enum _KneeFaultLevel { warning, error }

class KneeExtensionMetric extends CurlUpMetricBase {
  @override
  String get name => 'KneeExtension';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Highest fault level logged this rep, or null if none.
  _KneeFaultLevel? _loggedLevel;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    final angle = ctx.hipKneeAnkleAngle;

    if (angle == null) {
      // Ankle not visible — we can't assess knee extension this frame.
      // Silent skip; debug field tells us if this is a persistent state.
      _debugData['kneeExt'] = 'ankle hidden';
      return;
    }

    _debugData['kneeExt'] = '${angle.toStringAsFixed(1)}°';

    if (angle >= KneeExtensionConfig.ERROR_THRESHOLD) {
      ctx.resultIssues.feedback['Knee'] = '🔴 Chân thẳng quá!';
      _ensureLevel(ctx, _KneeFaultLevel.error);
    } else if (angle >= KneeExtensionConfig.WARNING_THRESHOLD) {
      ctx.resultIssues.feedback['Knee'] = '⚠️ Co gối thêm';
      _ensureLevel(ctx, _KneeFaultLevel.warning);
    } else {
      ctx.resultIssues.feedback['Knee'] = '✅ Gối tốt';
    }
  }

  /// Idempotent fault logger. Logs warning if no fault yet; upgrades to
  /// error in-place if a warning was logged earlier and the leg kept
  /// straightening.
  void _ensureLevel(RepContext ctx, _KneeFaultLevel level) {
    if (_loggedLevel == _KneeFaultLevel.error) return;

    final phase = ctx.curlUpState.toString().split('.').last.toUpperCase();

    if (level == _KneeFaultLevel.error) {
      _faults.clear();
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Knee',
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
        type: 'Knee',
        message: 'Gối hơi thẳng — co thêm để giữ tư thế McGill',
        affectsForm: false,
        priority: CurlUpFaultVoicePriority.kneeExtension,
        // No voiceMessage — yellow-band warnings stay quiet to avoid TTS spam.
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
  }
}
