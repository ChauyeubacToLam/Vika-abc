import 'plank_shoulder_tap_metric_base.dart';
import '../../../utils/debouncer.dart';

class HipRotationMetric extends PlankTapMetricBase {
  @override
  String get name => 'HipRotation';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _rotationDebouncer = Debouncer(requiredFrames: 3);

  double? _baselineHipY;
  double? _baselineHipWidthXNorm;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(
      PlankTapState from, PlankTapState to, int timestampMs) {
    if (to == PlankTapState.base) {
      _baselineHipY = null;
      _baselineHipWidthXNorm = null;
    }
  }

  @override
  void update(RepContext ctx) {
    if (ctx.scaleFactor <= 1e-6) return;

    if (ctx.state == PlankTapState.base) {
      _baselineHipY ??= ctx.hipY;
      _baselineHipWidthXNorm ??= ctx.hipWidthXNorm;
      ctx.resultIssues.feedback['Anti-Rotation'] = 'Hông ổn định';
      return;
    }

    if (_baselineHipY == null) return;

    final hipYVarianceNorm =
        (ctx.hipY - _baselineHipY!).abs() / ctx.scaleFactor;
    var hipWidthVarianceNorm = 0.0;
    if (ctx.hipWidthXNorm != null && _baselineHipWidthXNorm != null) {
      hipWidthVarianceNorm =
          (ctx.hipWidthXNorm! - _baselineHipWidthXNorm!).abs();
    }

    _debugData['hipYVarianceNorm'] = hipYVarianceNorm.toStringAsFixed(2);
    _debugData['hipWidthVarianceNorm'] =
        hipWidthVarianceNorm.toStringAsFixed(2);

    final isRotating =
        hipYVarianceNorm > PlankTapConfig.HIP_ROTATION_TOLERANCE ||
            hipWidthVarianceNorm > PlankTapConfig.HIP_WIDTH_DRIFT_TOLERANCE;

    if (_rotationDebouncer.update(isRotating)) {
      ctx.resultIssues.feedback['Anti-Rotation'] = 'Lắc hông! Siết bụng lại';
      if (!_faults.any((f) => f.type == 'hip_rotation')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name.toUpperCase(),
          type: 'hip_rotation',
          message: 'Hông bị vặn xoắn hoặc rớt xuống',
          affectsForm: true,
          priority: PlankTapVoicePriority.hipRotation,
          voiceMessage: 'Giữ hông cố định khi nhấc tay.',
        ));
      }
    } else {
      ctx.resultIssues.feedback['Anti-Rotation'] = 'Giữ tốt!';
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _rotationDebouncer.reset();
  }
}
