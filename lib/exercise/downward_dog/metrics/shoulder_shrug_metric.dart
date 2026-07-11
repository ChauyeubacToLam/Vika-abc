/* =========================================================================
   Metric 2: Shoulder Shrug / Impingement
   Priority: IMPORTANT — Ship Week 2-4

   Detects whether shoulders ride up toward the ears instead of drawing
   away from them. Gross detector only — the ear landmark is noisy.

   APPROACH:
   - Normalized vertical distance = (ear.y – shoulder.y) / scaleFactor.
   - Compare against the personal baseline captured at hold-still.
   - Good  : distance ≥ baseline × 0.8
   - Error : distance  < baseline × 0.6  [affectsForm = false — coaching only]

   PRE-FILTERING (ear landmark is the noisiest in the pose):
   - One Euro Filter on the ear Y-coordinate.
   - 7-frame rolling median before the threshold check.

   Vietnamese context:
   - Desk workers with stiff shoulders shrug into the trapezius to
     hold the arm line. Frame as coaching, not safety.

   THRESHOLDS (ESTIMATE — pending PT review):
   ┌──────────────────┬──────────────────┬──────────────────┐
   │ Week 1–4         │ Week 5–8         │ Week 9+          │
   ├──────────────────┼──────────────────┼──────────────────┤
   │ Error < 0.6×base │ Error < 0.6×base │ Error < 0.65×base│
   └──────────────────┴──────────────────┴──────────────────┘
   ========================================================================= */

import 'downward_dog_metric_base.dart';
import '../../../utils/debouncer.dart';

class ShoulderShrugConfig {
  /// Shrug threshold as a fraction of the personal ear-shoulder baseline.
  static const double ERROR_RATIO = 0.48;

  /// Good threshold — still OK if slightly lower than baseline.
  static const double GOOD_RATIO = 0.68;

  /// Rolling median window for the noisy ear landmark.
  static const int MEDIAN_WINDOW = 7;

  /// Consecutive frames before confirming a shrug fault.
  static const int CONFIRM_FRAMES = 10;
}

class ShoulderShrugMetric extends DownwardDogMetricBase {
  @override
  String get name => 'ShoulderShrug';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Rolling median buffer for the filtered ear Y.
  final List<double> _medianBuffer = [];

  final Debouncer _shrugDebouncer =
      Debouncer(requiredFrames: ShoulderShrugConfig.CONFIRM_FRAMES);

  double? _normalizedDist;
  MetricStatus _status = MetricStatus.pass;
  bool _isFaultingNow = false;

  /// Prevent instruction spam — coaching set once per hold.
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _normalizedDist;

  @override
  ThresholdBand? get threshold => ThresholdBand(
        faultBelow: (1.0 *
            ShoulderShrugConfig
                .ERROR_RATIO), // relative; actual check uses baseline
      );

  @override
  MetricStatus get status => _status;

  @override
  void update(HoldContext ctx) {
    _isFaultingNow = false;
    if (ctx.holdState != DownwardDogState.hold) {
      _status = MetricStatus.pass;
      return;
    }

    // No baseline yet — skip until hold-still completes.
    if (ctx.earShoulderBaseline == null || ctx.scaleFactor == null) {
      _status = MetricStatus.pass;
      _debugData['shrugStatus'] = 'awaiting baseline';
      return;
    }

    // Use raw distance (already smoothed by PoseSmoother in base class)
    final double filtered = ctx.earShoulderDist;

    // --- 7-frame rolling median ---
    _medianBuffer.add(filtered);
    while (_medianBuffer.length > ShoulderShrugConfig.MEDIAN_WINDOW) {
      _medianBuffer.removeAt(0);
    }
    final double smoothed = _median(_medianBuffer);

    // --- Normalize against scale factor ---
    final double normalized = smoothed / ctx.scaleFactor!;
    _normalizedDist = normalized;

    // --- Compare against personal baseline ---
    final double baseline = ctx.earShoulderBaseline!;
    final double ratio = normalized / baseline;

    _debugData['earShoulderNorm'] = normalized;
    _debugData['earShoulderBaseline'] = baseline;
    _debugData['shrugRatio'] = ratio;

    final bool isShrug = ratio < ShoulderShrugConfig.ERROR_RATIO;

    if (_shrugDebouncer.update(isShrug)) {
      _isFaultingNow = true;
      _status = MetricStatus.fault;
      ctx.resultIssues.feedback['shoulder_shrug'] =
          'Đẩy vai ra xa tai nhé, thả lỏng cổ.';
      if (!_instructionSet) {
        // Legacy UI instruction copy: Đẩy vai ra xa tai nhé, thả lỏng cổ.
        _instructionSet = true;
      }
      _logFault('HOLD', 'Shoulders shrugging toward ears');
    } else {
      _status = MetricStatus.pass;
      ctx.resultIssues.feedback['shoulder_shrug'] = 'Vai mở rộng, tốt!';
    }

    _debugData['shrugStatus'] =
        _status == MetricStatus.fault ? 'ERROR (shrug)' : 'good';
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'ShoulderShrug')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'ShoulderShrug',
        message: message,
        affectsForm: false, // coaching only
        voiceMessage: 'Thả vai ra xa tai',
        priority: DownwardDogFaultVoicePriority.shoulderShrug,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _medianBuffer.clear();
    _shrugDebouncer.reset();
    _normalizedDist = null;
    _status = MetricStatus.pass;
    _instructionSet = false;
    _isFaultingNow = false;
  }
}
