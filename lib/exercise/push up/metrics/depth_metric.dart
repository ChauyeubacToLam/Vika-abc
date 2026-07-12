/* =========================================================================
   Metric 2: Push-Up Depth (Elbow Flexion ROM)
   Priority: 🟡 IMPORTANT — Effectiveness + progression gating
   
   Tracks minimum elbow angle (β = SHOULDER→ELBOW→WRIST) per rep.
   Detects incomplete range of motion (shallow reps) and missed lockout.
   
   Vietnamese context:
   - Thresholds widened +5° from clinical norms (70-90°)
   - Desk workers with kyphosis + tight pecs lack shoulder mobility
   - Do NOT demand "chest to floor" — use angle, not Y-distance
   - Longer arm lengths in Vietnamese males can limit bottom clearance
   
   Evaluated PER-REP: minimum elbow angle recorded during descent/bottom,
   then checked when user returns to plank position.
   ========================================================================= */

import 'push_up_metric_base.dart';
import '../push_up.dart';

class DepthConfig {
  /// Good depth: elbow flexion reaches 80°-100° (widened for desk workers)
  static final double goodDepthMin = PushUpConfig.BOTTOM_ANGLE_RANGE[0];
  static final double goodDepthMax = PushUpConfig.BOTTOM_ANGLE_RANGE[1];

  /// Warning: 100°-110° — almost deep enough
  static const double SHALLOW_WARNING_MAX = 125.0;

  /// Error: > 110° — way too shallow, barely bending
  // (anything above SHALLOW_WARNING_MAX is error)

  /// Top lockout fallback before PushUp captures the user's plank baseline.
  static const double LOCKOUT_ANGLE = PushUpConfig.PLANK_ANGLE_THRESHOLD;
}

class DepthMetric extends PushUpMetricBase {
  @override
  String get name => 'Depth';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Track minimum elbow angle this rep (for post-rep analysis)
  double? _minElbowAngle;

  /// Prevent instruction spam — only set coaching once per rep.
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /// Public getter for summary display
  double? get minElbowAngle => _minElbowAngle;

  @override
  void update(RepContext ctx) {
    final beta = ctx.elbowAngle;

    // Track minimum elbow angle during descent and bottom
    if (ctx.pushUpState == PushUpState.descending ||
        ctx.pushUpState == PushUpState.bottom) {
      if (_minElbowAngle == null || beta < _minElbowAngle!) {
        _minElbowAngle = beta;
      }
    }

    _debugData['minElbow'] = _minElbowAngle?.toStringAsFixed(1) ?? 'N/A';
    _debugData['elbowAngle'] = beta.toStringAsFixed(1);

    // Live feedback during bottom — let user know if depth is good
    if (ctx.pushUpState == PushUpState.bottom) {
      if (beta <= DepthConfig.goodDepthMax &&
          beta >= DepthConfig.goodDepthMin) {
        ctx.resultIssues.feedback['Depth'] = 'Độ sâu chuẩn xác!';
      } else if (beta > DepthConfig.goodDepthMax &&
          beta <= DepthConfig.SHALLOW_WARNING_MAX) {
        ctx.resultIssues.feedback['Depth'] = 'Xuống thấp hơn một chút.';
      } else if (beta > DepthConfig.SHALLOW_WARNING_MAX) {
        ctx.resultIssues.feedback['Depth'] = 'Chưa đủ sâu! Hạ ngực xuống.';
      }
    }
  }

  /// Called by PushUp when rep completes (ascending → plank).
  /// Evaluates the recorded minimum elbow angle for this rep.
  void checkRepCompletion(PushUpState previousState, RepContext ctx) {
    if (_minElbowAngle == null) return;

    final min = _minElbowAngle!;

    if (min > DepthConfig.SHALLOW_WARNING_MAX) {
      // Error: way too shallow
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'depth',
        message: 'Quá nông (${min.toStringAsFixed(0)}°)',
        affectsForm: true,
      ));
      if (!_instructionSet) {
        // Legacy UI instruction copy: Chưa đủ sâu! Hạ ngực thấp hơn lần sau.
        _instructionSet = true;
      }
    } else if (min > DepthConfig.goodDepthMax) {
      // Warning: almost deep enough
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'depth',
        message: 'Hơi nông (${min.toStringAsFixed(0)}°)',
        affectsForm: false, // warning only, don't kill the rep
      ));
      if (!_instructionSet) {
        // Legacy UI instruction copy: Thử xuống sâu hơn một chút lần sau!
        _instructionSet = true;
      }
    }

    _debugData['depthResult'] =
        min <= DepthConfig.goodDepthMax ? 'good' : 'shallow';
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _minElbowAngle = null;
    _instructionSet = false;
  }
}
