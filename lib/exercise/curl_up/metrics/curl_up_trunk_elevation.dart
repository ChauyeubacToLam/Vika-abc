// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Trunk Elevation

   How far the trunk rises from the resting position — guards against
   a full sit-up which overloads the lumbar spine.

   Landmarks: SHOULDER (#11/#12), HIP (#23/#24), KNEE (#25/#26)
   Calculation: 3-point angle at the hip (shoulder-hip-knee)

   Baseline source priority:
   1. Hold-still activation (3s motionless, captured in isInStartPosition)
   2. Last resting frame before rep starts
   Baseline persists across reps — resting trunk angle doesn't change
   mid-set. Using relative angle (not trunk-from-horizontal) makes this
   proportion-independent across Vietnamese body types.

   When to check: Continuously during ascending and apex phases.
   Per-rep evaluation at the kinematic apex (apex → descending transition).

   Note: checkRepCompletion() is called explicitly by CurlUp at rep
   completion to add coaching instructions. This breaks the pure metric
   interface pattern — future refactor could move it into
   onStateTransition(descending, resting).
   ========================================================================= */

import 'curl_up_metric_base.dart';
import '../curl_up.dart';

class TrunkElevationMetric extends CurlUpMetricBase {
  @override
  String get name => 'TrunkElevation';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Baseline shoulder-hip-knee angle captured while lying flat.
  /// Persists across reps — never cleared by reset().
  double? _baselineAngle;

  /// Tracks the minimum angle this rep (maximum curl = smallest angle).
  double? _peakAngle;

  /// The computed elevation from resting at the apex.
  double? _peakElevation;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onRestingFrame(RepContext ctx) {
    // Use hold-still baseline as primary if we don't have one yet.
    // 3 seconds of guaranteed stillness beats a single resting frame.
    if (_baselineAngle == null && ctx.holdStillShoulderHipKnee != null) {
      _baselineAngle = ctx.holdStillShoulderHipKnee;
      _debugData['shBaseline'] = '${_baselineAngle!.toStringAsFixed(1)} (hold)';
      return;
    }

    // Refine with latest resting frame.
    _baselineAngle = ctx.shoulderHipKneeAngle;
    _debugData['shBaseline'] = _baselineAngle!.toStringAsFixed(1);
  }

  @override
  void update(RepContext ctx) {
    final angle = ctx.shoulderHipKneeAngle;

    // Track minimum angle (= peak curl position)
    if (_peakAngle == null || angle < _peakAngle!) {
      _peakAngle = angle;
    }

    // Compute current elevation from baseline
    final elevation = _baselineAngle != null
        ? (_baselineAngle! - angle).clamp(0.0, 90.0)
        : 0.0;

    _debugData['trunkElev'] = '${elevation.toStringAsFixed(1)}°';
    _debugData['shAngle'] = angle.toStringAsFixed(1);

    // Live feedback during active rep
    if (elevation > 45.0) {
      ctx.resultIssues.feedback['Range'] = '🔴 Lên quá cao!';
    } else if (elevation > 30.0) {
      ctx.resultIssues.feedback['Range'] = '⚠️ Hơi cao';
    } else {
      ctx.resultIssues.feedback['Range'] = '✅ Biên độ tốt';
    }
  }

  @override
  void onStateTransition(CurlUpState from, CurlUpState to, int timestampMs) {
    // Evaluate at the kinematic reversal point: apex → descending
    if (from == CurlUpState.apex && to == CurlUpState.descending) {
      _evaluateAtApex();
    }
  }

  void _evaluateAtApex() {
    if (_baselineAngle == null || _peakAngle == null) return;

    _peakElevation = (_baselineAngle! - _peakAngle!).clamp(0.0, 90.0);

    if (_peakElevation! > 45.0) {
      _logFault(
        'APEX',
        'Lên quá cao - chỉ cần nâng vai khỏi sàn!',
        affectsForm: true,
      );
    } else if (_peakElevation! >= 30.0) {
      _logFault(
        'APEX',
        'Giữ biên độ ngắn để bảo vệ lưng.',
        affectsForm: true,
      );
    }
    // < 30° = good, no fault logged
  }

  void _logFault(String phase, String message, {bool affectsForm = true}) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Range')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Range',
        message: message,
        affectsForm: affectsForm,
      ));
    }
  }

  /// Called by CurlUp when rep completes to add coaching instruction.
  void checkRepCompletion(RepContext ctx) {
    if (_peakElevation == null) return;

    if (_peakElevation! > 45.0) {
      ctx.resultIssues.addInstruction(
        'resting',
        'Range',
        'Lên quá cao - chỉ cần nâng vai khỏi sàn!',
      );
    } else if (_peakElevation! >= 30.0) {
      ctx.resultIssues.addInstruction(
        'resting',
        'Range',
        'Giữ biên độ ngắn để bảo vệ lưng.',
      );
    } else {
      ctx.resultIssues.addInstruction(
        'resting',
        'Range',
        'Biên độ rất chuẩn!',
      );
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    // Baseline persists — resting trunk angle doesn't change mid-set.
    _peakAngle = null;
    _peakElevation = null;
  }
}
