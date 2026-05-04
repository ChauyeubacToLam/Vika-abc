// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Trunk Elevation (Sit-Up vs. Curl-Up Control)

   Priority: 🔴 CRITICAL (chronic risk of disc herniation)

   What it measures:
   How far the trunk has tilted from its baseline lying-flat angle at the
   apex of the rep. Guards against full sit-up territory (>45°) which
   transfers load to hip flexors and imposes high lumbar compression.

   Signal: trunkAngle = horizontal angle of shoulder→hip segment.
   Baseline-relative: peak_elevation = peak_trunkAngle - baseline_trunkAngle.

   WHY trunkAngle, NOT shoulder-hip-knee (SHK):
   SHK has knee as one of its three points, so any knee movement
   contaminates SHK readings. trunkAngle only depends on shoulder.y and
   hip.y — pure trunk signal, knee-invariant. Camera tilt offset is
   absorbed by baseline subtraction (assuming camera doesn't move during
   the set; AR sagittal calibration is a future ticket).

   Direction:
     - Lying flat:  trunkAngle ≈ baseline (some camera-tilt offset)
     - Curling up:  trunkAngle INCREASES
     - Returning:   trunkAngle DECREASES back toward baseline
   So peak = max during the rep (was min when we used SHK).

   Baseline source priority:
   - First non-null trunkAngle from a resting frame.
   - Refined every subsequent resting frame to track natural rest drift.

   Threshold table (peak elevation = peak_trunkAngle - baseline):
     >  45°: ERROR     — full sit-up, lumbar load (affectsForm=true)
     30–45°: WARNING   — too high, coach toward shorter ROM (affectsForm=false)
     15–30°: GOOD      — proper curl-up range
     <  15°: WARNING   — too shallow, coach toward more height (affectsForm=false)

   Evaluation timing:
   - update() logs "too high" faults the moment threshold crosses
   - checkRepCompletion() handles "too shallow" + praise (only knowable
     after peak is established)
   - Warning → error upgrade is in-place via _ensureLevel()
   ========================================================================= */

import 'curl_up_metric_base.dart';
import '../curl_up.dart';

class TrunkElevationConfig {
  /// Peak elevation above which the rep is a full sit-up — fail the rep.
  static const double ERROR_HIGH = 20.0;

  /// Upper bound of the safe range. Above = "too high" warning.
  static const double WARNING_HIGH = 13.0;

  /// Lower bound of the safe range. Below = "too shallow" warning.
  static const double WARNING_LOW = 5.0;
}

enum _HighFaultLevel { warning, error }

class TrunkElevationMetric extends CurlUpMetricBase {
  @override
  String get name => 'TrunkElevation';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Personal baseline for trunk angle from horizontal at rest.
  /// Persists across reps; refreshes during resting frames.
  double? _baselineTrunkAngle;

  /// Maximum trunkAngle reached this rep (= deepest curl).
  double? _peakTrunkAngle;

  /// Computed peak elevation, set at rep completion for debug.
  double? _peakElevation;

  /// Highest fault level logged this rep, or null if none.
  _HighFaultLevel? _loggedLevel;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /// Refresh baseline whenever the user is at rest. Single-frame
  /// replacement is fine — resting trunk angle is stable signal.
  @override
  void onRestingFrame(RepContext ctx) {
    _baselineTrunkAngle = ctx.trunkAngle;
    _debugData['trunkBase'] = _baselineTrunkAngle!.toStringAsFixed(1);
  }

  /// Active rep — track peak (max), write live feedback, log faults
  /// the moment "too high" thresholds cross.
  @override
  void update(RepContext ctx) {
    final angle = ctx.trunkAngle;

    // Track maximum trunkAngle = deepest curl point.
    if (_peakTrunkAngle == null || angle > _peakTrunkAngle!) {
      _peakTrunkAngle = angle;
    }

    final base = _baselineTrunkAngle;
    if (base == null) return;

    final liveElevation = (angle - base).clamp(0.0, 90.0);

    _debugData['trunkAngle'] = angle.toStringAsFixed(1);
    _debugData['trunkElev'] = '${liveElevation.toStringAsFixed(1)}°';

    if (liveElevation > TrunkElevationConfig.ERROR_HIGH) {
      ctx.resultIssues.feedback['Range'] = '🔴 Lên quá cao!';
      _ensureLevel(ctx, _HighFaultLevel.error);
    } else if (liveElevation > TrunkElevationConfig.WARNING_HIGH) {
      ctx.resultIssues.feedback['Range'] = '⚠️ Hơi cao';
      _ensureLevel(ctx, _HighFaultLevel.warning);
    } else if (liveElevation < TrunkElevationConfig.WARNING_LOW) {
      // Could just be early in ascent — don't log "too shallow" here,
      // that's a rep-end check.
      ctx.resultIssues.feedback['Range'] = '⚠️ Cuộn cao thêm';
    } else {
      ctx.resultIssues.feedback['Range'] = '✅ Biên độ tốt';
    }
  }

  /// Idempotent fault logger. Logs warning if no fault yet; upgrades
  /// to error in-place if user keeps climbing past 45°.
  void _ensureLevel(RepContext ctx, _HighFaultLevel level) {
    if (_loggedLevel == _HighFaultLevel.error) return;

    if (level == _HighFaultLevel.error) {
      _faults.clear();
      _faults.add(FaultRecord(
        phase: 'APEX',
        type: 'Range',
        message: 'Lên quá cao — chỉ cần nâng vai khỏi sàn',
        affectsForm: true,
        voiceMessage: 'Chỉ nâng vai',
        priority: CurlUpFaultVoicePriority.trunkTooHigh,
      ));
      ctx.resultIssues.addInstruction('resting', 'Range',
          'Rep tới chỉ cần nâng vai khỏi sàn — giữ ROM ngắn để bảo vệ lưng.');
      _loggedLevel = _HighFaultLevel.error;
      return;
    }

    if (_loggedLevel == null) {
      _faults.add(FaultRecord(
        phase: 'APEX',
        type: 'Range',
        message: 'Hơi cao — giữ biên độ ngắn để bảo vệ lưng',
        affectsForm: false,
        priority: CurlUpFaultVoicePriority.trunkTooHigh,
      ));
      ctx.resultIssues.addInstruction(
          'resting', 'Range', 'Rep tới hạ thấp một chút — giữ biên độ ngắn.');
      _loggedLevel = _HighFaultLevel.warning;
    }
  }

  /// Called by CurlUp at rep completion. Handles cases that can ONLY
  /// be evaluated post-peak: too-shallow and the praise case.
  void checkRepCompletion(RepContext ctx) {
    final base = _baselineTrunkAngle;
    final peak = _peakTrunkAngle;
    if (base == null || peak == null) return;

    _peakElevation = (peak - base).clamp(0.0, 90.0);
    _debugData['peakElev'] = '${_peakElevation!.toStringAsFixed(1)}°';

    // High-elevation fault already logged in update() — that takes
    // precedence over a too-shallow check.
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
      ctx.resultIssues.addInstruction('resting', 'Range', 'Biên độ rất chuẩn!');
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _peakTrunkAngle = null;
    _peakElevation = null;
    _loggedLevel = null;
    // _baselineTrunkAngle preserved across reps — resting trunk angle
    // is stable within a set.
  }
}
