// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Neck Pulling (Cervical Hyperflexion)

   Priority: 🔴 CRITICAL (acute injury risk to the cervical spine)

   What it measures:
   How far the head/neck has flexed relative to the personal resting
   baseline. Detects chin-to-chest pulling, the classic compensation
   when abs fatigue and the user uses their arms to yank the head up.
   The cervical spine is highly susceptible to structural buckling under
   combined axial and shear loads — pulling the neck places profound strain
   on intervertebral discs and the sternocleidomastoid muscles.

   Landmarks: EAR (#7/#8), SHOULDER (#11/#12), HIP (#23/#24)
   Calculation: Interior angle at shoulder — calculateAngle(Ear, Shoulder, Hip).
                Joint-frame measurement. Pulling chin to chest moves the ear
                toward the shoulder, decreasing the angle. Subtraction
                against personal baseline cancels world-frame effects.

   Why a personalized baseline (Vietnamese desk-worker context):
   Thoracic kyphosis (forward head posture) is highly prevalent in
   desk-bound office workers — the 25-45 ICP cohort. Their resting neck
   posture already shows partial flexion compared to a textbook neutral
   spine. A hardcoded absolute angle threshold would either mislabel
   their normal resting posture as "pulled" (false positive) or be too
   lenient for users with neutral posture (false negative). Baseline
   captured at hold-still adapts to the individual.

   Baseline source priority (set ONCE per set):
   1. Hold-still activation snapshot (3s motionless capture). Strongest signal.
   2. Resting-frame averaging (5 samples). Fallback when hold-still missing.
   Once set, baseline does NOT refine — head posture during a set is stable
   enough that further refinement would just track within-set drift noise.

   Threshold table:
     Deviation > 15°: ERROR    — chin-to-chest pull (affectsForm=true)
     Deviation 12-15°: WARNING — neck flexing, coach toward neutral (affectsForm=false)
     Deviation < 12°: GOOD

   Evaluation timing:
   Continuous during ascending AND descending. update() logs the fault the
   moment the threshold crosses; upgrades from warning → error in-place if
   the user keeps pulling. Spec mentions "concentric phase" but a held
   chin-tuck during descent is the same cervical strain — checking both
   active phases catches it without missing anything.
   ========================================================================= */

import 'curl_up_metric_base.dart';

class NeckPullingConfig {
  /// Deviation from personal baseline that triggers a warning.
  static const double WARNING_DEVIATION = 18.0;

  /// Deviation from personal baseline that triggers an error.
  static const double ERROR_DEVIATION = 24.0;

  /// Number of resting frames averaged when hold-still snapshot is missing.
  static const int BASELINE_SAMPLE_COUNT = 5;
}

/// Tracks the highest fault level reached so far this rep.
enum _NeckFaultLevel { warning, error }

class NeckPullingMetric extends CurlUpMetricBase {
  @override
  String get name => 'NeckPulling';
  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _neckDeviation;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: NeckPullingConfig.WARNING_DEVIATION,
        faultAbove: NeckPullingConfig.ERROR_DEVIATION,
      );

  @override
  MetricStatus get status => _status;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  double? _neckAngle;
  double? _neckDeviation;
  MetricStatus _status = MetricStatus.pass;

  /// Personal baseline — ear-shoulder-hip interior angle while lying flat.
  /// Persists across reps; never cleared by reset().
  double? _baselineAngle;

  /// Fallback averaging state — used only when hold-still is unavailable.
  double _baselineSum = 0.0;
  int _baselineFrames = 0;

  /// Highest fault level logged this rep, or null if none.
  _NeckFaultLevel? _loggedLevel;

  /// Establish the personal baseline. Hold-still wins; averaging is a
  /// fallback. Once a baseline is set, it stays for the whole set.
  @override
  void onRestingFrame(RepContext ctx) {
    if (_baselineAngle != null) return;

    if (ctx.holdStillEarShoulderHip != null) {
      _baselineAngle = ctx.holdStillEarShoulderHip;
      _debugData['neckBaseline'] = _baselineAngle;
      return;
    }

    // Hold-still missing — average across multiple resting frames.
    _baselineSum += ctx.earShoulderHipAngle;
    _baselineFrames++;
    if (_baselineFrames >= NeckPullingConfig.BASELINE_SAMPLE_COUNT) {
      _baselineAngle = _baselineSum / _baselineFrames;
      _debugData['neckBaseline'] = _baselineAngle;
    } else {
      _debugData['neckBaseline'] = 'sampling...';
    }
  }

  /// Active rep — compute deviation from baseline, write live feedback,
  /// log faults the moment thresholds cross.
  @override
  void update(RepContext ctx) {
    _neckAngle = ctx.earShoulderHipAngle;
    _debugData['neckAngle'] = _neckAngle;

    final base = _baselineAngle;
    if (base == null) {
      _debugData['neckDev'] = 'no baseline';
      return;
    }

    // Deviation: baseline is the relaxed (large) angle. Pulling chin to
    // chest moves the ear toward the shoulder, shrinking the interior
    // angle, so deviation = baseline - current.
    final deviation = (base - _neckAngle!).clamp(0.0, 90.0);
    _neckDeviation = deviation;
    _debugData['neckDev'] = deviation;

    if (deviation >= NeckPullingConfig.ERROR_DEVIATION) {
      _status = MetricStatus.fault;
      ctx.resultIssues.feedback['Neck'] = '🔴 Đừng kéo cổ!';
      _ensureLevel(ctx, _NeckFaultLevel.error);
    } else if (deviation >= NeckPullingConfig.WARNING_DEVIATION) {
      _status = MetricStatus.near;
      ctx.resultIssues.feedback['Neck'] = '⚠️ Giữ cổ thẳng';
      _ensureLevel(ctx, _NeckFaultLevel.warning);
    } else {
      _status = MetricStatus.pass;
      ctx.resultIssues.feedback['Neck'] = '✅ Cổ tốt';
    }
  }

  /// Idempotent fault logger. Logs warning if no fault yet; upgrades to
  /// error in-place if a warning was logged earlier and deviation kept
  /// climbing.
  void _ensureLevel(RepContext ctx, _NeckFaultLevel level) {
    if (_loggedLevel == _NeckFaultLevel.error) return;

    final phase = ctx.curlUpState.toString().split('.').last.toUpperCase();

    if (level == _NeckFaultLevel.error) {
      _faults.clear();
      _faults.add(FaultRecord(
        phase: phase,
        type: 'neck_pull',
        message: 'Kéo cổ quá mạnh — giữ đầu trung tính',
        affectsForm: true,
        voiceMessage: 'Không kéo cổ',
        priority: CurlUpFaultVoicePriority.neckPulling,
      ));
      // Legacy UI instruction copy: Rep tới giữ cằm trung tính — đừng dùng tay kéo đầu lên.
      _loggedLevel = _NeckFaultLevel.error;
      return;
    }

    if (_loggedLevel == null) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'neck_pull',
        message: 'Hơi căng cổ — giữ đầu thẳng hàng với lưng',
        affectsForm: false,
        priority: CurlUpFaultVoicePriority.neckPulling,
        // No voiceMessage — yellow-band warnings stay quiet to avoid TTS spam.
      ));
      // Legacy UI instruction copy: Rep tới giữ cổ thẳng tự nhiên — đừng gập cằm.
      _loggedLevel = _NeckFaultLevel.warning;
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _loggedLevel = null;
    _neckAngle = null;
    _neckDeviation = null;
    _status = MetricStatus.pass;
    // _baselineAngle and averaging state intentionally preserved —
    // resting neck posture doesn't change mid-set.
  }
}
