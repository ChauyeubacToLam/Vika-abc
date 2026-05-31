import 'leg_raise_metric_base.dart';
import '../../../utils/debouncer.dart';

class KneeStraightnessMetric extends LegRaiseMetricBase {
  @override
  String get name => 'KneeStraightness';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 3);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LegRaiseRepContext ctx) {
    if (ctx.state == LegRaiseState.lying) return; // Không bắt lúc đang nằm thở

    // Yêu cầu góc gối >= 160 độ trong suốt quá trình rep
    if (_faultDebouncer.update(ctx.kneeStraightnessAngle < 160.0)) {
      if (!_faults.any((f) => f.type == 'BentKnee')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'BentKnee',
          message: 'Gập gối làm giảm áp lực cơ bụng',
          voiceMessage: 'Cố gắng duỗi thẳng gối ra nhé',
          affectsForm: true,
          priority: LegRaiseFaultPriority.bentKnee,
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _faultDebouncer.reset();
  }
}
