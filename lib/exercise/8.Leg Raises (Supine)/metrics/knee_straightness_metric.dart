import 'leg_raise_metric_base.dart';
import '../../../utils/debouncer.dart';

class KneeStraightnessMetric extends LegRaiseMetricBase {
  @override
  String get name => 'KneeStraightness';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  double? _kneeStraightnessAngle;

  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 3);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _kneeStraightnessAngle;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningBelow: LegRaiseConfig.START_KNEE_STRAIGHT_MIN + 10.0,
        faultBelow: LegRaiseConfig.START_KNEE_STRAIGHT_MIN,
      );

  @override
  void update(LegRaiseRepContext ctx) {
    if (ctx.state == LegRaiseState.lying) return; // Không bắt lúc đang nằm thở

    // Yêu cầu góc gối >= 160 độ trong suốt quá trình rep
    _kneeStraightnessAngle = ctx.kneeStraightnessAngle;
    _debugData['kneeStraightnessAngle'] = ctx.kneeStraightnessAngle;

    if (_faultDebouncer.update(
        ctx.kneeStraightnessAngle < LegRaiseConfig.START_KNEE_STRAIGHT_MIN)) {
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
    _debugData.clear();
    _kneeStraightnessAngle = null;
    _faultDebouncer.reset();
  }
}
