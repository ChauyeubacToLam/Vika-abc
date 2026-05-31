import 'dead_bug_metric_base.dart';

class TempoMetric extends DeadBugMetricBase {
  @override
  String get name => 'Tempo';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _extendingStartMs;
  double? extendingDuration;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(DeadBugState from, DeadBugState to, int timestampMs) {
    if (to == DeadBugState.extending) {
      _extendingStartMs = timestampMs;
    } else if (to == DeadBugState.hold && _extendingStartMs != null) {
      extendingDuration = (timestampMs - _extendingStartMs!) / 1000.0;
    }
  }

  @override
  void update(DeadBugRepContext ctx) {}

  void evaluateRep(DeadBugRepContext ctx) {
    // Không được thả tay chân rơi rầm xuống (< 1.5s là quá nhanh)
    if (extendingDuration != null && extendingDuration! < 1.5) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'Tempo',
        message:
            'Thả rơi tay/chân nhanh (${extendingDuration!.toStringAsFixed(1)}s)',
        voiceMessage:
            'Hạ tay chân chậm lại khoảng 2 giây để kích hoạt cơ bụng sâu!',
        affectsForm: true,
        priority: DeadBugFaultPriority.tempo,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _extendingStartMs = null;
    extendingDuration = null;
  }
}
