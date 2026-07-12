import 'plank_shoulder_tap_metric_base.dart';

class ClearTapMetric extends PlankTapMetricBase {
  @override
  String get name => 'ClearTap';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  bool _reachedTapThisRep = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(
      PlankTapState from, PlankTapState to, int timestampMs) {
    if (to == PlankTapState.tap) {
      _reachedTapThisRep = true;
    }
  }

  @override
  void update(RepContext ctx) {
    _debugData['tap_wristShoulderDist'] =
        ctx.activeWristShoulderDistNorm.toStringAsFixed(2);
    _debugData['tap_wristLift'] = ctx.wristLiftNorm.toStringAsFixed(2);

    if (ctx.state == PlankTapState.tap) {
      ctx.resultIssues.feedback['Tap'] = 'Chạm dứt khoát!';
    } else if (ctx.state == PlankTapState.lifting) {
      ctx.resultIssues.feedback['Tap'] = 'Kéo tay tới vai...';
    }
  }

  @override
  void evaluateRepEnd(RepContext ctx) {
    if (!_reachedTapThisRep) {
      _faults.add(FaultRecord(
        phase: 'LIFTING',
        type: 'tap',
        message: 'Không chạm tới vai',
        affectsForm: true,
        priority: PlankTapVoicePriority.clearTap,
        voiceMessage: 'Chạm tay dứt khoát lên vai.',
      ));
      // Legacy UI instruction copy: Nhịp trước chạm chưa tới vai.
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _reachedTapThisRep = false;
  }
}
