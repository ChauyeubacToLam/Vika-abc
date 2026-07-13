import 'high_plank_metric_base.dart';
import '../../../utils/hold_seconds_accumulator.dart';

class TimerMetric extends HighPlankMetricBase {
  @override
  String get name => 'PerfectTimer';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int totalHoldingTimeMs = 0;
  int? _lastTickMs;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(
      HighPlankState from, HighPlankState to, int timestampMs) {
    if (to == HighPlankState.holding) {
      _lastTickMs = timestampMs;
    } else {
      _lastTickMs = null;
    }
  }

  @override
  void update(HighPlankRepContext ctx) {
    if (ctx.state == HighPlankState.holding) {
      if (_lastTickMs == null) {
        _lastTickMs = ctx.frameTimestampMs;
      } else {
        final delta = ctx.frameTimestampMs - _lastTickMs!;
        _lastTickMs = ctx.frameTimestampMs;
        if (delta >= HoldSecondsAccumulator.minFrameDeltaMs &&
            delta <= HoldSecondsAccumulator.maxFrameDeltaMs) {
          totalHoldingTimeMs += delta;
        }
      }
    }
    _debugData['holdTime'] = (totalHoldingTimeMs / 1000.0).toStringAsFixed(1);

    double currentSeconds = totalHoldingTimeMs / 1000.0;
    _debugData['holdClock'] = '${currentSeconds.toStringAsFixed(1)}s';
  }

  @override
  void reset() {
    faultsCount = 0;
    _faults.clear();
    _debugData.clear();
    totalHoldingTimeMs = 0;
    _lastTickMs = null;
  }

  void pause() {
    _lastTickMs = null;
  }

  void resetForNextHold() => reset();
}
