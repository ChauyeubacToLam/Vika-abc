import '../../utils/hold_seconds_accumulator.dart';
import '../fault_record.dart';
import 'hold_phase.dart';

abstract interface class HoldTimerFrame {
  HoldPhase get holdPhase;
  int get frameTimestampMs;
}

class TimerMetric {
  String get name => 'PerfectTimer';

  int faultsCount = 0;
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int totalHoldingTimeMs = 0;
  int? _lastTickMs;

  List<FaultRecord> get faults => _faults;
  Map<String, dynamic> get debugData => _debugData;

  void onStateTransition(
    HoldPhase from,
    HoldPhase to,
    int timestampMs,
  ) {
    if (to == HoldPhase.holding) {
      _lastTickMs = timestampMs;
    } else {
      _lastTickMs = null;
    }
  }

  void update(HoldTimerFrame frame) {
    updateAt(
      phase: frame.holdPhase,
      timestampMs: frame.frameTimestampMs,
    );
  }

  void updateAt({
    required HoldPhase phase,
    required int timestampMs,
  }) {
    if (phase == HoldPhase.holding) {
      if (_lastTickMs == null) {
        _lastTickMs = timestampMs;
      } else {
        final delta = timestampMs - _lastTickMs!;
        _lastTickMs = timestampMs;
        if (delta >= HoldSecondsAccumulator.minFrameDeltaMs &&
            delta <= HoldSecondsAccumulator.maxFrameDeltaMs) {
          totalHoldingTimeMs += delta;
        }
      }
    }
    _debugData['holdTime'] = (totalHoldingTimeMs / 1000.0).toStringAsFixed(1);

    final currentSeconds = totalHoldingTimeMs / 1000.0;
    _debugData['holdClock'] = '${currentSeconds.toStringAsFixed(1)}s';
  }

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
