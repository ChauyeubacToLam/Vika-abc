import 'plank_up_down_metric_base.dart';

class HipRotationMetric extends PlankMetricBase {
  @override
  String get name => 'Hip Rotation';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _maxHipY;
  double? _minHipY;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(PlankRepContext ctx) {
    if (_maxHipY == null || ctx.hipY > _maxHipY!) _maxHipY = ctx.hipY;
    if (_minHipY == null || ctx.hipY < _minHipY!) _minHipY = ctx.hipY;

    final scale = ctx.scaleFactor;
    if (scale == null || scale <= 1e-6) return;
    double variance = (_maxHipY! - _minHipY!).abs() / scale;
    _debugData['Hip_Variance'] = variance.toStringAsFixed(2);

    if (variance > PlankConfig.HIP_Y_ROTATION_TOLERANCE) {
      ctx.resultIssues.feedback['Rotation'] = 'Lắc hông quá nhiều';
      if (!_faults.any((f) => f.type == 'hip_rotation')) {
        _faults.add(FaultRecord(
          phase: ctx.currentState.name,
          type: 'hip_rotation',
          message: 'Hông mất ổn định khi đổi tay',
          affectsForm: true,
          voiceMessage: 'Giữ hông cố định, không lắc lư khi đẩy người!',
          priority: PlankFaultVoicePriority.hipRotation,
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _maxHipY = null;
    _minHipY = null;
  }
}
