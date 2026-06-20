import 'dead_bug_metric_base.dart';
import '../../../utils/debouncer.dart';

class FloorContactMetric extends DeadBugMetricBase {
  @override
  String get name => 'FloorContact';

  static const double _floorContactAngle = 165.0;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 3);
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _debugData['maxExtensionAngle'] is num
      ? (_debugData['maxExtensionAngle'] as num).toDouble()
      : double.tryParse('${_debugData['maxExtensionAngle'] ?? ''}');

  @override
  ThresholdBand? get threshold =>
      const ThresholdBand(warningAbove: 155.0, faultAbove: _floorContactAngle);

  @override
  void update(DeadBugRepContext ctx) {
    if (ctx.state != DeadBugState.extending && ctx.state != DeadBugState.hold) {
      return;
    }

    final maxAngle = ctx.maxExtensionAngle;
    _debugData['maxExtensionAngle'] = maxAngle;

    if (_faultDebouncer.update(maxAngle >= _floorContactAngle)) {
      ctx.resultIssues.feedback['Floor'] = 'Đừng để tay hoặc chân chạm sàn.';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          ctx.state.name,
          'Floor',
          'Hạ tay/chân gần sàn nhưng giữ lơ lửng, không chạm sàn.',
        );
        _instructionSet = true;
      }
      if (!_faults.any((f) => f.type == 'FloorContact')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'FloorContact',
          message: 'Tay hoặc chân chạm sàn',
          voiceMessage: 'Giữ tay và chân lơ lửng, đừng chạm sàn',
          affectsForm: true,
          priority: DeadBugFaultPriority.floorContact,
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _faultDebouncer.reset();
    _instructionSet = false;
  }
}
