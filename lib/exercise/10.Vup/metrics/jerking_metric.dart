import 'v_up_metric_base.dart';
import '../../../utils/debouncer.dart';

class JerkingMetric extends VUpMetricBase {
  @override
  String get name => 'Jerking';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _lastTimeMs;
  double? _lastShoulderY;
  double? _lastAnkleY;
  double _maxVelocity = 0;
  final Debouncer _faultDebouncer =
      Debouncer(requiredFrames: VUpConfig.JERKING_FAULT_FRAMES);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(VUpRepContext ctx) {
    if (ctx.state != VUpState.rising || ctx.scaleFactor == null) {
      _faultDebouncer.update(false);
      return;
    }

    if (_lastShoulderY != null && _lastTimeMs != null) {
      double dt = (ctx.frameTimestampMs - _lastTimeMs!) / 1000.0;
      if (dt > 0) {
        double dShld = (_lastShoulderY! - ctx.shoulderY) / ctx.scaleFactor!;
        double dAnkle = (_lastAnkleY! - ctx.ankleY) / ctx.scaleFactor!;

        // Lấy vận tốc lớn hơn giữa vai và gót chân
        double vel = (dShld > dAnkle ? dShld : dAnkle) / dt;

        if (vel > _maxVelocity) _maxVelocity = vel;
        _debugData['maxVelocity'] = _maxVelocity.toStringAsFixed(2);

        final isSustainedJerk =
            _faultDebouncer.update(vel > VUpConfig.JERKING_VELOCITY_THRESHOLD);
        if (isSustainedJerk && !_faults.any((f) => f.type == 'Jerking')) {
          _faults.add(FaultRecord(
            phase: ctx.state.name,
            type: 'Jerking',
            message: 'Dùng lực quán tính để giật lên',
            voiceMessage: 'Dùng cơ bụng để cuộn lên, không giật lấy đà!',
            affectsForm: true,
            priority: VUpFaultPriority.jerking,
          ));
        }
      }
    }
    _lastShoulderY = ctx.shoulderY;
    _lastAnkleY = ctx.ankleY;
    _lastTimeMs = ctx.frameTimestampMs;
  }

  @override
  void reset() {
    _faults.clear();
    _lastTimeMs = null;
    _lastShoulderY = null;
    _lastAnkleY = null;
    _maxVelocity = 0;
    _faultDebouncer.reset();
  }
}
