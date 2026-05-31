import 'bow_pose_metric_base.dart';

class HoldDurationMetric extends BowPoseMetricBase {
  @override
  String get name => 'HoldDuration';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _holdStartMs;
  double _currentHoldSeconds = 0.0;
  double _maxHoldSeconds = 0.0;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(BowPoseState from, BowPoseState to, int timestampMs) {
    if (to == BowPoseState.hold) {
      _holdStartMs = timestampMs;
    } else if (from == BowPoseState.hold) {
      _holdStartMs = null;
    }
  }

  @override
  void update(RepContext ctx) {
    if (ctx.bowPoseState == BowPoseState.hold && _holdStartMs != null) {
      _currentHoldSeconds = (ctx.frameTimestamp - _holdStartMs!) / 1000.0;
      if (_currentHoldSeconds > _maxHoldSeconds) {
        _maxHoldSeconds = _currentHoldSeconds;
      }
      _debugData['holdTime'] = '${_currentHoldSeconds.toStringAsFixed(1)}s';
      ctx.resultIssues.feedback['Timer'] =
          'Giữ: ${_currentHoldSeconds.toStringAsFixed(1)}s';
    }
  }

  @override
  void evaluateRep(RepContext ctx) {
    if (_maxHoldSeconds < 15.0) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'HoldDuration',
        message: 'Giữ quá ngắn (${_maxHoldSeconds.toStringAsFixed(1)}s < 15s)',
        affectsForm: true,
      ));
    }
    ctx.resultIssues.feedback['MaxHold'] =
        '${_maxHoldSeconds.toStringAsFixed(1)}s';
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _holdStartMs = null;
    _currentHoldSeconds = 0.0;
    _maxHoldSeconds = 0.0;
  }
}
