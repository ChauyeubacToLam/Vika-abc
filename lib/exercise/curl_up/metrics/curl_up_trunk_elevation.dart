// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Curl Up Metric: Trunk Elevation

   How far the trunk rises from the resting position — guards against
   a full sit-up which overloads the lumbar spine.

   Landmarks: SHOULDER (#11/#12), HIP (#23/#24), KNEE (#25/#26)
   Calculation: 3-point angle at the hip (shoulder-hip-knee)

   When to check: Continuously during ascending and apex phases.
   Per-rep evaluation at the kinematic apex (apex → descending transition).
   ========================================================================= */

import 'curl_up_metric_base.dart';
import '../curl_up.dart';

class TrunkElevationMetric extends CurlUpMetricBase {
  @override
  String get name => 'TrunkElevation';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Baseline shoulder-hip-knee angle captured while lying flat.
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
  void update(RepContext ctx) {
    final angle = ctx.shoulderHipKneeAngle;

    // Capture baseline from lying state (first frames before motion)
    _baselineAngle ??= angle;

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
    _baselineAngle = null;
    _peakAngle = null;
    _peakElevation = null;
  }
}
