/* =========================================================================
   Metric 1: Squat Depth (Knee Flexion Angle)
   Priority: CRITICAL — Ship Day 1
   
   Measures interior angle at the knee joint (hip-knee-ankle).
   Primary indicator of squat depth + gates rep counting.
   ========================================================================= */

import 'squat_metric_base.dart';
import '../squat.dart';

class DepthMetricConfig {
  /// Knee angle range considered "at bottom" (good depth)
  static const List<int> GOOD_DEPTH_RANGE = [80, 115];

  /// Below this = deep squat (celebrated, not penalized)
  static const int DEEP_SQUAT_THRESHOLD = 80;
}

class DepthMetric extends SquatMetricBase {
  @override
  String get name => 'Depth';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Tracks minimum knee angle this rep (for post-rep analysis & tempo)
  double? minKneeAngle;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  Map<String, String> update(RepContext ctx) {
    // Track minimum knee angle across the rep
    if (minKneeAngle == null || ctx.kneeAngle < minKneeAngle!) {
      minKneeAngle = ctx.kneeAngle;
    }

    _debugData['minKneeAngle'] = minKneeAngle?.toStringAsFixed(1) ?? 'N/A';

    final feedback = <String, String>{};

    if (ctx.kneeAngle < DepthMetricConfig.DEEP_SQUAT_THRESHOLD) {
      feedback['Depth'] = 'Deep Squat!';
    } else if (ctx.kneeAngle >= DepthMetricConfig.GOOD_DEPTH_RANGE[0] &&
        ctx.kneeAngle <= DepthMetricConfig.GOOD_DEPTH_RANGE[1]) {
      feedback['Depth'] = 'Good Depth';
    } else if (ctx.squatState == SquatState.descending &&
        ctx.kneeAngle > DepthMetricConfig.GOOD_DEPTH_RANGE[1] &&
        ctx.kneeY >= ctx.hipY) {
      // Knee hasn't dropped below hip yet — encourage going lower
      feedback['Depth'] = 'Go Lower';
    } else {
      feedback['Depth'] = 'Good Depth';
    }

    return feedback;
  }

  /// Called by Squat when rep completes to check if depth was sufficient.
  /// (User stood up from descending without reaching bottom = shallow)
  void checkRepCompletion(SquatState finalState) {
    final phase = finalState.toString().split('.').last.toUpperCase();
    if (finalState != SquatState.ascending) {
      _logFault(phase, 'Too Shallow (Missed Depth)');
    }
  }

  void _logFault(String phase, String message) {
    // Only log first fault of this type per phase
    if (!_faults.any((f) => f.phase == phase && f.type == 'Depth')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Depth',
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    minKneeAngle = null;
  }
}
