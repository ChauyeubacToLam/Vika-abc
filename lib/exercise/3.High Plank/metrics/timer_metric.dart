import 'high_plank_metric_base.dart';

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
  void onStateTransition(HighPlankState from, HighPlankState to, int timestampMs) {
    if (to == HighPlankState.holding) {
      _lastTickMs = timestampMs;
    } else {
      _lastTickMs = null;
    }
  }

  @override
  void update(HighPlankRepContext ctx) {
    if (ctx.state == HighPlankState.holding && _lastTickMs != null) {
      int delta = ctx.frameTimestampMs - _lastTickMs!;
      totalHoldingTimeMs += delta;
      _lastTickMs = ctx.frameTimestampMs;
    }
    _debugData['holdTime'] = (totalHoldingTimeMs / 1000.0).toStringAsFixed(1);
    
    // UI instruction showing clock
    ctx.resultIssues.addInstruction(ctx.state.name, 'Clock', '${(totalHoldingTimeMs / 1000.0).toStringAsFixed(1)}s / 30s');
  }

  @override
  void reset() {}
}