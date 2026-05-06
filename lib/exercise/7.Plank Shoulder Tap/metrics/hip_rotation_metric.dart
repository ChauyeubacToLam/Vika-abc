import 'plank_shoulder_tap_metric_base.dart';
import '../../../utils/debouncer.dart';

class HipRotationMetric extends PlankTapMetricBase {
  @override
  String get name => 'HipRotation';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _rotationDebouncer = Debouncer(requiredFrames: 3);

  double? _baselineHipY;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(PlankTapState from, PlankTapState to, int timestampMs) {
    if (to == PlankTapState.base) {
      // Cập nhật lại baseline mỗi khi về tư thế 4 chân
      _baselineHipY = null;
    }
  }

  @override
  void update(RepContext ctx) {
    if (ctx.state == PlankTapState.base) {
      // Học lại vị trí hông chuẩn khi ở tư thế 4 chân vững chãi
      _baselineHipY = ctx.hipY;
      ctx.resultIssues.feedback['Anti-Rotation'] = 'Hông ổn định';
      return;
    }

    if (_baselineHipY == null) return;

    // Tính độ lệch Y của Hông khi nhấc tay (Tương đương rớt hông hoặc nảy hông do xoay người)
    double hipVarianceNorm = (ctx.hipY - _baselineHipY!).abs() / (ctx.scaleFactor == 0 ? 1 : ctx.scaleFactor);
    _debugData['hipVarianceNorm'] = hipVarianceNorm.toStringAsFixed(2);

    bool isRotating = hipVarianceNorm > PlankTapConfig.HIP_ROTATION_TOLERANCE;

    if (_rotationDebouncer.update(isRotating)) {
      ctx.resultIssues.feedback['Anti-Rotation'] = 'Lắc hông! Siết bụng lại';
      if (!_faults.any((f) => f.type == 'HipRotation')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name.toUpperCase(), type: 'HipRotation', message: 'Hông bị vặn xoắn/rớt',
          affectsForm: true, priority: PlankTapVoicePriority.hipRotation, voiceMessage: 'Giữ hông cố định, không vặn mình khi nhấc tay!'
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