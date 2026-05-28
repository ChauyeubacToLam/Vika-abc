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
    
    // Tính toán tiến độ % để gửi ra UI (0.0 đến 1.0)
    double targetSeconds = 30.0; // Hoặc có thể gọi từ HighPlankConfig.TARGET_TIME_MS / 1000.0
    double currentSeconds = totalHoldingTimeMs / 1000.0;
    double progress = (currentSeconds / targetSeconds).clamp(0.0, 1.0);
    
    // Gửi instruction chứa text để UI hiển thị số giây
    ctx.resultIssues.addInstruction(ctx.state.name, 'Clock', '${currentSeconds.toStringAsFixed(1)}s / ${targetSeconds.toStringAsFixed(0)}s');
    
    // Gửi instruction chứa progress để UI vẽ vòng tròn
    ctx.resultIssues.addInstruction(ctx.state.name, 'ClockProgress', progress.toString());
  }

  @override
  void reset() {}
}