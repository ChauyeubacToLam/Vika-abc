import 'sit_up_metric_base.dart';

class JerkingMetric extends SitUpMetricBase {
  @override
  String get name => 'Jerking';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _risingStartMs;
  double? _lastShoulderY;
  int? _lastTimeMs;
  double _maxVelocity = 0;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(SitUpState from, SitUpState to, int timestampMs) {
    if (to == SitUpState.rising) {
      _risingStartMs = timestampMs;
    }
  }

  @override
  void update(SitUpRepContext ctx) {
    if (ctx.state != SitUpState.rising ||
        _risingStartMs == null ||
        ctx.scaleFactor == null) {
      return;
    }

    if (ctx.frameTimestampMs - _risingStartMs! > 500) {
      return;
    }

    if (_lastShoulderY != null && _lastTimeMs != null) {
      double dt = (ctx.frameTimestampMs - _lastTimeMs!) / 1000.0;
      if (dt > 0) {
        double dy = (_lastShoulderY! - ctx.shoulderY) / ctx.scaleFactor!;
        double velocity = dy / dt; // pixels per second (normalized)

        if (velocity > _maxVelocity) {
          _maxVelocity = velocity;
        }

        if (velocity > 2.0 && !_faults.any((f) => f.type == 'Jerking')) {
          _faults.add(FaultRecord(
            phase: ctx.state.name,
            type: 'Jerking',
            message: 'Dùng lực giật/quăng người',
            voiceMessage: 'Lên từ từ, đừng giật thân người!',
            affectsForm: true,
            priority: SitUpFaultPriority.jerking,
          ));
        }
      }
    }
    _lastShoulderY = ctx.shoulderY;
    _lastTimeMs = ctx.frameTimestampMs;
  }

  @override
  void reset() {
    _faults.clear();
    _risingStartMs = null;
    _lastShoulderY = null;
    _lastTimeMs = null;
    _maxVelocity = 0;
  }
}
