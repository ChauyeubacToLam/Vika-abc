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

    double variance = (_maxHipY! - _minHipY!).abs() / (ctx.scaleFactor ?? 1.0);
    _debugData['Hip_Variance'] = variance.toStringAsFixed(2);

    if (variance > PlankConfig.HIP_Y_ROTATION_TOLERANCE) {
      ctx.resultIssues.feedback['Rotation'] = 'Lắc hông quá nhiều';
      if (!_faults.any((f) => f.type == 'Rotation')) {
        _faults.add(FaultRecord(
          phase: ctx.currentState.name,
          type: 'Rotation',
          message: 'Hông mất ổn định khi đổi tay',
          affectsForm: true,
          voiceMessage: 'Giữ hông cố định, không lắc lư!',
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