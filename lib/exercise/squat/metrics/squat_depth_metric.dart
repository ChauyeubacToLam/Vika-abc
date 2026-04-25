// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Metric 1: Squat Depth (Knee Flexion Angle)
   Priority: CRITICAL - Ship Day 1

   Measures interior angle at the knee joint (hip-knee-ankle).
   Primary indicator of squat depth + gates rep counting.
   ========================================================================= */

import 'squat_metric_base.dart';
import '../squat.dart';

class DepthMetricConfig {
  /// Knee angle range considered "at bottom" (good depth)
  static const List<int> GOOD_DEPTH_RANGE =
      SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD;

  /// Below this = deep squat (celebrated, not penalized)
  static final int DEEP_SQUAT_THRESHOLD =
      SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[0];
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
  void update(RepContext ctx) {
    // Track minimum knee angle across the rep
    if (minKneeAngle == null || ctx.kneeAngle < minKneeAngle!) {
      minKneeAngle = ctx.kneeAngle;
    }

    _debugData['minKneeAngle'] = minKneeAngle?.toStringAsFixed(1) ?? 'N/A';

    if (ctx.kneeAngle < DepthMetricConfig.DEEP_SQUAT_THRESHOLD) {
      ctx.resultIssues.feedback['Depth'] = 'Deep Squat!';
    } else if (ctx.kneeAngle >= DepthMetricConfig.GOOD_DEPTH_RANGE[0] &&
        ctx.kneeAngle <= DepthMetricConfig.GOOD_DEPTH_RANGE[1]) {
      ctx.resultIssues.feedback['Depth'] = 'Good Depth';
    } else if (ctx.squatState == SquatState.descending &&
        ctx.kneeAngle > DepthMetricConfig.GOOD_DEPTH_RANGE[1] &&
        ctx.kneeY >= ctx.hipY) {
      ctx.resultIssues.feedback['Depth'] = 'Go Lower';
    } else {
      ctx.resultIssues.feedback['Depth'] = 'Good Depth';
    }
  }

  /// Called by Squat when rep completes to check if depth was sufficient.
  /// If the user returned to standing without reaching bottom, mark it shallow.
  void checkRepCompletion({
    required SquatState finalState,
    required bool reachedBottom,
    required RepContext ctx,
  }) {
    final phase = finalState.toString().split('.').last.toUpperCase();
    if (!reachedBottom) {
      _logFault(phase, 'Too Shallow (Missed Depth)', 'Thap hon nua');
      ctx.resultIssues
          .addInstruction('standing', 'Depth', 'Go deeper next time!');
    }
  }

  void _logFault(String phase, String message, String? voiceMessage) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Depth')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Depth',
        message: message,
        voiceMessage: voiceMessage,
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
