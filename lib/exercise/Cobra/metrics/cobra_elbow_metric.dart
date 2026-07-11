// ignore_for_file: curly_braces_in_flow_control_structures
import 'cobra_metric_base.dart';
import '../cobra.dart';
import '../../../utils/debouncer.dart';
import '../../../utils/pose_math_helpers.dart';

/// MET-1: Elbow Flexion Angle (Lockout Detector)
/// CRITICAL priority — #1 most reliable metric.
/// Locked elbows transfer all bodyweight through joints → lumbar injury risk.
class CobraElbowMetric extends CobraMetricBase {
  @override
  String get name => 'ElbowFlexion';

  // Beginner thresholds
  static const double _goodMin = 90.0;
  static const double _goodMax = 140.0;
  static const double _errorMin = 170.0; // locked out

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final StickyDebouncer _lockoutDebouncer = StickyDebouncer(requiredFrames: 8);
  final StickyDebouncer _warningDebouncer = StickyDebouncer(requiredFrames: 6);
  bool _isFaultingNow = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    _isFaultingNow = false;
    if (ctx.state == CobraState.setup) return;
    if (ctx.shoulder == null || ctx.elbow == null || ctx.wrist == null) return;

    final angle = calculateAngleNormalized(
      firstPoint: ctx.shoulder!,
      midPoint: ctx.elbow!,
      lastPoint: ctx.wrist!,
    );

    _debugData['elbowAngle'] = angle.toStringAsFixed(1);

    final phase = ctx.state.name;

    // Error: locked out (>170°)
    if (_lockoutDebouncer.update(angle >= _errorMin)) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Elbow'] = '⚠️ Khuỷu tay duỗi quá thẳng!';
      // Legacy UI instruction copy: Giữ khuỷu tay hơi cong. Đừng duỗi thẳng hoàn toàn.
      _logFault(phase, 'Elbow locked out', 'ElbowLockout');
    }
    // Warning: approaching lockout (140-160°)
    else if (_warningDebouncer.update(angle > _goodMax && angle < _errorMin)) {
      ctx.resultIssues.feedback['Elbow'] = 'Cong khuỷu tay thêm chút';
    }
    // Good range
    else if (angle >= _goodMin && angle <= _goodMax) {
      ctx.resultIssues.feedback['Elbow'] = 'Khuỷu tay tốt ✓';
    }
  }

  void _logFault(String phase, String message, String type) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _lockoutDebouncer.reset();
    _warningDebouncer.reset();
    _isFaultingNow = false;
  }
}
