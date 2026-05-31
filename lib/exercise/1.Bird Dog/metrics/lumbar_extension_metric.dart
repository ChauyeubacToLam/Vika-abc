import 'bird_dog_metric_base.dart';
import '../../../utils/debouncer.dart';

class LumbarExtensionMetric extends BirdDogMetricBase {
  @override
  String get name => 'LumbarHyperextension';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 3);

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(BirdDogRepContext ctx) {
    if (ctx.state != BirdDogState.hold_extended) return;

    _debugData['shaAngle'] = ctx.shoulderHipAnkleAngle.toStringAsFixed(1);

    // Chân văng lên quá cao làm góc vai-hông-gót > 185 độ -> võng lưng
    if (_faultDebouncer.update(ctx.shoulderHipAnkleAngle > 185.0)) {
      ctx.resultIssues.feedback['Spine'] = 'Lưng bị võng!';
      if (!_faults.any((f) => f.type == 'Lumbar')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Lumbar',
          message: 'Đưa chân quá cao gây võng lưng',
          voiceMessage: 'Hạ thấp chân xuống một chút',
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
  }
}
