import 'high_plank_metric_base.dart';
import '../high_plank.dart';

class ElbowMetric extends HighPlankMetricBase {
  @override
  String get name => 'BentElbows';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  bool _isFaulting = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(HighPlankRepContext ctx) {
    if (ctx.shoulderElbowWristAngle < HighPlankConfig.DROPPING_ARM_ANGLE) {
      if (!_isFaulting) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'BentElbow',
          message: 'Khuỷu tay bị gập',
          voiceMessage: 'Duỗi thẳng cánh tay ra',
          affectsForm: true,
          priority: HighPlankFaultPriority.bentElbows,
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