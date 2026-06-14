import 'bird_dog_metric_base.dart';
import '../../../utils/debouncer.dart';

class LumbarExtensionMetric extends BirdDogMetricBase {
  @override
  String get name => 'LumbarHyperextension';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 3);

  static const double _maxLegAboveTrunkDegrees = 25.0;
  double? _legAboveTrunk;
  MetricStatus _status = MetricStatus.pass;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;
  @override
  double? get value => _legAboveTrunk;
  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: 18.0,
        faultAbove: _maxLegAboveTrunkDegrees,
      );
  @override
  MetricStatus get status => _status;

  @override
  void update(BirdDogRepContext ctx) {
    final legAboveTrunk =
        ctx.activeLegHorizontalAngle - ctx.trunkHorizontalAngle;
    _legAboveTrunk = legAboveTrunk;
    final ankleAboveHip = ctx.activeAnkleY < ctx.hipY;

    _debugData['shaAngle'] = ctx.shoulderHipAnkleAngle;
    _debugData['legAboveTrunk'] = legAboveTrunk;
    _debugData['ankleAboveHip'] = ankleAboveHip;

    final isHyperextending =
        ankleAboveHip && legAboveTrunk > _maxLegAboveTrunkDegrees;
    _status = isHyperextending
        ? MetricStatus.fault
        : ankleAboveHip && legAboveTrunk > 18.0
            ? MetricStatus.near
            : MetricStatus.pass;
    if (ctx.state != BirdDogState.hold_extended) return;

    if (_faultDebouncer.update(isHyperextending)) {
      ctx.resultIssues.feedback['Spine'] = 'Lưng bị võng!';
      if (!_faults.any((f) => f.type == 'Lumbar')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Lumbar',
          message: 'Đưa chân quá cao gây võng lưng',
          voiceMessage: 'Hạ chân xuống ngang thân.',
          affectsForm: true,
          priority: BirdDogFaultPriority.lumbarExtension,
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _faultDebouncer.reset();
    _legAboveTrunk = null;
    _status = MetricStatus.pass;
  }
}
