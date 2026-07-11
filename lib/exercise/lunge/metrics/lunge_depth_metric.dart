// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Lunge Metric: Depth

   Lead knee angle — how deep the user lunges.

   Landmarks: HIP (#23/#24), KNEE (#25/#26), ANKLE (#27/#28) — lead leg
   Calculation: 3-point angle at the lead knee (hip-knee-ankle)

   When to check: Continuously during descending and bottom phases.
   Per-rep evaluation at rep completion (checkRepCompletion) to verify
   the user reached sufficient depth without going too deep.
   ========================================================================= */

import 'lunge_metric_base.dart';
import '../lunge.dart';

class LungeDepthConfig {
  /// Lead knee angle range considered good depth.
  static const List<int> GOOD_DEPTH_RANGE = [55, 125];

  /// Below this = too deep
  static const int TOO_DEEP_THRESHOLD = 55;

  /// Shallow warning zone: 110° – 140°
  static const int SHALLOW_WARN_THRESHOLD = 150;
}

class LungeDepthMetric extends LungeMetricBase {
  @override
  String get name => 'Depth';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Tracks minimum lead knee angle this rep (for post-rep analysis)
  double? minKneeAngle;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LungeRepContext ctx) {
    // Track minimum lead knee angle across the rep
    if (minKneeAngle == null || ctx.leadKneeAngle < minKneeAngle!) {
      minKneeAngle = ctx.leadKneeAngle;
    }

    _debugData['minLeadKneeAngle'] = minKneeAngle?.toStringAsFixed(1) ?? 'N/A';

    final phase = ctx.lungeState.toString().split('.').last.toUpperCase();

    if (ctx.leadKneeAngle < LungeDepthConfig.TOO_DEEP_THRESHOLD) {
      // Too deep
      ctx.resultIssues.feedback['Depth'] = 'Quá sâu! Đứng lên một chút';
      _logFault(phase, 'Too deep! Come up a bit');
    } else if (ctx.leadKneeAngle >= LungeDepthConfig.GOOD_DEPTH_RANGE[0] &&
        ctx.leadKneeAngle <= LungeDepthConfig.GOOD_DEPTH_RANGE[1]) {
      // Good depth
      ctx.resultIssues.feedback['Depth'] = 'Độ sâu tốt!';
    } else if (ctx.lungeState == LungeState.descending &&
        ctx.leadKneeAngle > LungeDepthConfig.GOOD_DEPTH_RANGE[1] &&
        ctx.leadKneeAngle <= LungeDepthConfig.SHALLOW_WARN_THRESHOLD) {
      // Shallow — still descending, encourage going lower
      ctx.resultIssues.feedback['Depth'] = 'Xuống thấp hơn';
    } else if (ctx.leadKneeAngle > LungeDepthConfig.SHALLOW_WARN_THRESHOLD) {
      // Too shallow
      ctx.resultIssues.feedback['Depth'] = 'Chưa đủ sâu';
    } else {
      ctx.resultIssues.feedback['Depth'] = 'Độ sâu tốt!';
    }
  }

  // Called by Lunge when rep completes to check if depth was sufficient.
  // (User stood up from descending without reaching bottom = shallow)
  void checkRepCompletion(LungeState finalState, LungeRepContext ctx) {
    final phase = finalState.toString().split('.').last.toUpperCase();

    if (minKneeAngle == null) return;

    if (minKneeAngle! > LungeDepthConfig.GOOD_DEPTH_RANGE[1]) {
      // Never reached good depth
      _logFault(phase, 'Not deep enough', voiceMessage: 'Xuống thấp hơn');
      // Legacy UI instruction copy: Xuống sâu hơn lần sau!
    } else if (minKneeAngle! < LungeDepthConfig.TOO_DEEP_THRESHOLD) {
      // Went too deep
      _logFault(phase, 'Too deep! Come up a bit');
      // Legacy UI instruction copy: Đừng xuống quá sâu, giữ gối ở 90°.
    }
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
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
