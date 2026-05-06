import 'high_plank_metric_base.dart';
import '../high_plank.dart';

class PikedHipMetric extends HighPlankMetricBase {
  @override
  String get name => 'PikedHips';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  bool _isFaulting = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(HighPlankRepContext ctx) {
    // Góc cơ thể giảm (<155) VÀ hông nằm trên đường chuẩn (Âm trong ML Kit Y)
    if (ctx.shoulderHipAnkleAngle < HighPlankConfig.DROPPING_PIKE_ANGLE && ctx.hipDeviation < -0.05) {
      if (!_isFaulting) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Piked',
          message: 'Chổng mông làm mất tác dụng bài tập',
          voiceMessage: 'Hạ thấp mông xuống bằng với vai',
          affectsForm: true,
          priority: HighPlankFaultPriority.pikedHips,
        ));
        _isFaulting = true;
      }
    } else {
      _isFaulting = false;
    }
  }

  @override
  void reset() {}
}