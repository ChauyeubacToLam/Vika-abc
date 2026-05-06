import 'high_plank_metric_base.dart';
import '../high_plank.dart';

class SaggingMetric extends HighPlankMetricBase {
  @override
  String get name => 'SaggingHips';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  bool _isFaulting = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(HighPlankRepContext ctx) {
    _debugData['hipDev'] = ctx.hipDeviation.toStringAsFixed(3);

    // Hông sụt xuống (Dương trong ML Kit Y)
    if (ctx.hipDeviation > HighPlankConfig.DROPPING_SAG_DEVIATION) {
      ctx.resultIssues.feedback['Core'] = 'Võng lưng!';
      if (!_isFaulting) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Sagging',
          message: 'Võng lưng gây áp lực cột sống',
          voiceMessage: 'Siết chặt bụng, nâng hông lên một chút',
          affectsForm: true,
          priority: HighPlankFaultPriority.hipSagging,
        ));
        _isFaulting = true;
      }
    } else {
      ctx.resultIssues.feedback['Core'] = 'Lưng phẳng';
      _isFaulting = false;
    }
  }

  @override
  void reset() {} // Metric tĩnh không xóa faults mỗi rep
}