import 'v_up_metric_base.dart';
import '../../../utils/debouncer.dart';

class KneeExtensionMetric extends VUpMetricBase {
  @override
  String get name => 'KneeExtension';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 3);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(VUpRepContext ctx) {
    if (ctx.state == VUpState.lying) return;

    if (_faultDebouncer
        .update(ctx.hipKneeAnkleAngle < VUpConfig.ACTIVE_KNEE_MIN)) {
      if (!_faults.any((f) => f.type == 'knee')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'knee',
          message: 'Gập gối làm mất lực đòn bẩy',
          voiceMessage: 'Nhớ giữ thẳng gối trong suốt quá trình gập nhé',
          affectsForm: true,
          priority: VUpFaultPriority.bentKnee,
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
