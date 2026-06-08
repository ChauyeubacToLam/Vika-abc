// ignore_for_file: curly_braces_in_flow_control_structures
import 'low_lunge_metric_base.dart';
import '../low_lunge.dart';
import '../../../utils/debouncer.dart';
import '../../../utils/pose_math_helpers.dart';

/// MET-2: Cervical Safety.
/// Gross detector for cranking the neck back during Low Lunge hold.
class CervicalSafetyMetric extends LowLungeMetricBase {
  @override
  String get name => 'CervicalSafety';

  static const double _goodMin = 140.0;
  static const double _errorMax = 140.0;
  static const double _minEarConfidence = 0.5;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final StickyDebouncer _errorDebouncer =
      StickyDebouncer(requiredFrames: 8, currentState: false);

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LowLungeContext ctx) {
    if (ctx.state != LowLungeState.holding) return;
    if (ctx.ear == null || ctx.frontShoulder == null || ctx.frontHip == null) {
      return;
    }

    if (ctx.ear!.likelihood < _minEarConfidence) {
      _debugData['cervicalAngle'] = 'low_conf';
      return;
    }

    final cervicalAngle = calculateAngleNormalized(
      firstPoint: ctx.ear!,
      midPoint: ctx.frontShoulder!,
      lastPoint: ctx.frontHip!,
    );
    _debugData['cervicalAngle'] = cervicalAngle.toStringAsFixed(1);

    if (_errorDebouncer.update(cervicalAngle < _errorMax)) {
      ctx.resultIssues.feedback['Neck'] = 'Nhìn về trước thôi nhé';
      ctx.resultIssues.addInstruction(
        'holding',
        'cervicalDanger',
        'Đừng ngửa đầu ra sau. Giữ cổ dài và thoải mái.',
      );
      _logFault(ctx.state.name, 'Neck cranked back', 'CervicalDanger');
    } else if (cervicalAngle >= _goodMin) {
      ctx.resultIssues.feedback['Neck'] = 'Cổ thoải mái ✓';
    }
  }

  void _logFault(String phase, String message, String type) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: message,
        affectsForm: false,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _errorDebouncer.reset();
  }
}
