// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Trunk Elevation (Sit-Up vs. Curl-Up Control)

   Priority: 🔴 CRITICAL (chronic risk of disc herniation)

   What it measures:
   How far the trunk has elevated from the lying-flat baseline at the apex
   of the rep. Guards against full sit-up territory, which transfers load
   from the abdominal wall to the hip flexors and imposes up to 3,300 N of
   compressive force on the lumbar vertebrae.

   Landmarks: SHOULDER (#11/#12), HIP (#23/#24), KNEE (#25/#26)
   Calculation: Interior angle at hip — calculateAngle(Shoulder, Hip, Knee).
                Joint-frame measurement — invariant to camera tilt and hip
                drift. Subtraction against personal baseline cancels any
                world-frame effects.

   Baseline source priority (set ONCE per set, persists across reps):
   1. Hold-still activation snapshot (3s motionless capture in
      isInStartPosition). Strongest signal.
   2. Resting frame between reps. Refined via onRestingFrame.

   Threshold table (per VinaFit spec — peak elevation = baseline - peak angle):
     >  45°: ERROR     — full sit-up, lumbar load (affectsForm=true)
     30–45°: WARNING   — too high, coach toward shorter ROM (affectsForm=false)
     15–30°: GOOD      — proper curl-up range
     <  15°: WARNING   — too shallow, coach toward more height (affectsForm=false)

   Evaluation timing (mirrors squat pattern):
   - "Too high" violations are knowable the moment the threshold is crossed.
     update() logs the fault + instruction immediately. Upgrades from
     warning → error in-place if the user continues past 45°.
   - "Too shallow" can only be known at rep end (low mid-rep elevation just
     means user is still ascending). checkRepCompletion() handles it, plus
     the praise case for clean reps.
   ========================================================================= */

import 'curl_up_metric_base.dart';
import '../curl_up.dart';

class TrunkElevationConfig {
  /// Peak elevation above which the rep is a full sit-up — fail the rep.
  static const double ERROR_HIGH = 45.0;

  /// Upper bound of the safe range. Above this is a "too high" warning
  /// (affectsForm=false, doesn't fail the rep).
  static const double WARNING_HIGH = 30.0;

  /// Lower bound of the safe range. Below this is a "too shallow" warning.
  static const double WARNING_LOW = 15.0;
}

/// Tracks the highest fault level reached so far this rep.
/// `null` (field unset) = no high-elevation fault yet (could still get a
/// too-shallow at rep end).
/// `warning` = crossed 30° but not 45°.
/// `error` = crossed 45° (sit-up territory).
enum _HighFaultLevel { warning, error }

class TrunkElevationMetric extends CurlUpMetricBase {
  @override
  String get name => 'TrunkElevation';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Personal baseline — shoulder-hip-knee interior angle while lying flat.
  /// Persists across reps; never cleared by reset().
  double? _baselineAngle;

  /// Minimum angle reached this rep (= deepest curl point).
  double? _peakAngle;

  /// Peak elevation = baseline - _peakAngle, set at rep completion for debug.
  double? _peakElevation;

  /// Highest fault level logged this rep, or null if none.
  _HighFaultLevel? _loggedLevel;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /// Refine the personal baseline whenever the user is lying flat between
  /// reps. Hold-still gets first crack; resting frames refine it.
  @override
  void onRestingFrame(RepContext ctx) {
    if (_baselineAngle == null && ctx.holdStillShoulderHipKnee != null) {
      _baselineAngle = ctx.holdStillShoulderHipKnee;
      _debugData['shBaseline'] = '${_baselineAngle!.toStringAsFixed(1)} (hold)';
      return;
    }

    _baselineAngle = ctx.shoulderHipKneeAngle;
    _debugData['shBaseline'] = _baselineAngle!.toStringAsFixed(1);
  }

  /// Active rep — track peak, write live feedback, log faults the moment
  /// high-elevation thresholds cross.
  @override
  void update(RepContext ctx) {
    final angle = ctx.shoulderHipKneeAngle;

    if (_peakAngle == null || angle < _peakAngle!) {
      _peakAngle = angle;
    }

    final base = _baselineAngle;
    if (base == null) return;

    final liveElevation = (base - angle).clamp(0.0, 90.0);

    _debugData['shAngle'] = angle.toStringAsFixed(1);
    _debugData['trunkElev'] = '${liveElevation.toStringAsFixed(1)}°';

    if (liveElevation > TrunkElevationConfig.ERROR_HIGH) {
      ctx.resultIssues.feedback['Range'] = '🔴 Lên quá cao!';
      _ensureLevel(ctx, _HighFaultLevel.error);
    } else if (liveElevation > TrunkElevationConfig.WARNING_HIGH) {
      ctx.resultIssues.feedback['Range'] = '⚠️ Hơi cao';
      _ensureLevel(ctx, _HighFaultLevel.warning);
    } else if (liveElevation < TrunkElevationConfig.WARNING_LOW) {
      // User is still below the safe range. Could just be early in the
      // ascent — don't log "too shallow" here, that's a rep-end check.
      ctx.resultIssues.feedback['Range'] = '⚠️ Cuộn cao thêm';
    } else {
      ctx.resultIssues.feedback['Range'] = '✅ Biên độ tốt';
    }
  }

  /// Idempotent fault logger. Logs warning if no fault yet; upgrades to
  /// error in-place if a warning was logged earlier and elevation kept
  /// climbing.
  void _ensureLevel(RepContext ctx, _HighFaultLevel level) {
    if (_loggedLevel == _HighFaultLevel.error) return; // already at top

    if (level == _HighFaultLevel.error) {
      // Upgrade: wipe any prior warning and log error in its place.
      _faults.clear();
      _faults.add(FaultRecord(
        phase: 'APEX',
        type: 'Range',
        message: 'Lên quá cao — chỉ cần nâng vai khỏi sàn',
        affectsForm: true,
        voiceMessage: 'Chỉ nâng vai',
        priority: CurlUpFaultVoicePriority.trunkTooHigh,
      ));
      // addInstruction overwrites by (phase, type), so this naturally
      // replaces any prior warning instruction.
      ctx.resultIssues.addInstruction('resting', 'Range',
          'Rep tới chỉ cần nâng vai khỏi sàn — giữ ROM ngắn để bảo vệ lưng.');
      _loggedLevel = _HighFaultLevel.error;
      return;
    }

    // level == warning, and we have nothing logged yet.
    if (_loggedLevel == null) {
      _faults.add(FaultRecord(
        phase: 'APEX',
        type: 'Range',
        message: 'Hơi cao — giữ biên độ ngắn để bảo vệ lưng',
        affectsForm: false,
        priority: CurlUpFaultVoicePriority.trunkTooHigh,
        // No voiceMessage — yellow-band warnings stay quiet to avoid TTS spam.
      ));
      ctx.resultIssues.addInstruction(
          'resting', 'Range', 'Rep tới hạ thấp một chút — giữ biên độ ngắn.');
      _loggedLevel = _HighFaultLevel.warning;
    }
  }

  /// Called by CurlUp at rep completion. Handles the cases that can ONLY
  /// be evaluated post-peak: too-shallow and the praise case for clean reps.
  void checkRepCompletion(RepContext ctx) {
    final base = _baselineAngle;
    final peak = _peakAngle;
    if (base == null || peak == null) return;

    _peakElevation = (base - peak).clamp(0.0, 90.0);
    _debugData['peakElev'] = '${_peakElevation!.toStringAsFixed(1)}°';

    // High-elevation fault already logged in update() — that takes
    // precedence over a too-shallow check (you can't have BOTH).
    if (_loggedLevel != null) return;

    if (_peakElevation! < TrunkElevationConfig.WARNING_LOW) {
      _faults.add(FaultRecord(
        phase: 'APEX',
        type: 'Range',
        message: 'Cuộn chưa đủ — nâng cao vai hơn',
        affectsForm: false,
        voiceMessage: 'Cuộn cao hơn',
        priority: CurlUpFaultVoicePriority.trunkTooShallow,
      ));
      ctx.resultIssues
          .addInstruction('resting', 'Range', 'Rep tới cuộn cao hơn một chút.');
    } else {
      // Clean rep in the 15-30° good zone. Praise on the rest screen.
      ctx.resultIssues.addInstruction('resting', 'Range', 'Biên độ rất chuẩn!');
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _peakAngle = null;
    _peakElevation = null;
    _loggedLevel = null;
    // _baselineAngle intentionally preserved — resting trunk angle doesn't
    // change mid-set.
  }
}
