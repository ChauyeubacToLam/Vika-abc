/* =========================================================================
   Metric 2: Shoulder Shrug (Are shoulders hiking up?)
   Priority: 🔴 SAFETY — wrong muscles, neck pain + headaches.
 
   DISTANCE metric WITH baseline. Measures the ear→shoulder gap normalized
   by shoulder→hip (scaleFactor), compared to the hold-still resting ratio.
   Shoulders creeping toward the ears shrinks the gap → ratio drops.
 
       baseline = (earToShoulder / shoulderToHip)  at hold-still
       current  = (earToShoulder / shoulderToHip)  during exercise
       shrink   = (baseline - current) / baseline     (positive = shrugging)
 
   Thresholds (Week 1-4, ESTIMATE — PT review). Reconciled to the doc's
   Threshold Table (12% / 18%), not the metric-body's 15%/20% prose:
     Good:    shrink < 12%
     Warning: 12-18%        (10-frame debounce)
     Error:   > 18%         (12-frame debounce, affectsForm = true)
 
   Baseline is essential — if it was never captured (ear hidden at
   hold-still) the metric stays inactive.
   ========================================================================= */
 
import '../wall_push_up.dart';
import 'package:vika/utils/debouncer.dart';
 
class ShoulderShrugConfig {
  static const double WARNING_SHRINK = 0.12; // 12% gap decrease
  static const double ERROR_SHRINK = 0.18; // 18% gap decrease
}
 
class ShoulderShrugMetric extends WallPushUpMetricBase {
  @override
  String get name => 'ShoulderShrug';
 
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
 
  final Debouncer _warningDebouncer = Debouncer(requiredFrames: 10);
  final Debouncer _errorDebouncer = Debouncer(requiredFrames: 12);
 
  /// Resting ratio captured at hold-still. Persists for the whole set.
  double? _baseline;
  bool _instructionSet = false;
 
  @override
  List<FaultRecord> get faults => _faults;
 
  @override
  Map<String, dynamic> get debugData => _debugData;
 
  @override
  void captureBaseline(double? value) {
    if (value != null && value > 0) _baseline = value;
  }
 
  @override
  void update(RepContext ctx) {
    final ratio = ctx.shrugRatio;
    if (ratio == null || _baseline == null) return;
 
    final shrink = (_baseline! - ratio) / _baseline!; // + = shrugging
    final phase = ctx.state.toString().split('.').last.toUpperCase();
    _debugData['shrugShrink'] = '${(shrink * 100).toStringAsFixed(0)}%';
 
    final bool isError = shrink > ShoulderShrugConfig.ERROR_SHRINK;
    final bool isWarning = shrink > ShoulderShrugConfig.WARNING_SHRINK &&
        shrink <= ShoulderShrugConfig.ERROR_SHRINK;
 
    final bool errorConfirmed = _errorDebouncer.update(isError);
    final bool warningConfirmed = _warningDebouncer.update(isWarning);
 
    if (errorConfirmed) {
      ctx.resultIssues.feedback['Shoulders'] = 'Hạ vai xuống, đừng nhún vai!';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
            'standing', 'Shoulders', 'Hạ vai xuống — đừng nhún vai lên tai.');
        _instructionSet = true;
      }
      _logFault(phase, 'Nhún vai quá mức',
          voiceMessage: 'Hạ vai xuống', affectsForm: true);
    } else if (warningConfirmed) {
      ctx.resultIssues.feedback['Shoulders'] = 'Vai hơi nhún, thả vai xuống.';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
            'standing', 'Shoulders', 'Vai hơi nhún — thả lỏng vai xuống.');
        _instructionSet = true;
      }
      _logFault(phase, 'Vai hơi nhún',
          voiceMessage: 'Hạ vai xuống', affectsForm: false);
    } else {
      ctx.resultIssues.feedback['Shoulders'] = 'Vai thả lỏng tốt!';
    }
 
    _debugData['shrugStatus'] =
        _faults.isNotEmpty ? '⚠️ ${_faults.last.message}' : '✅';
  }
 
  void _logFault(String phase, String message,
      {String? voiceMessage, required bool affectsForm}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Shoulders',
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: affectsForm,
      ));
    }
  }
 
  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _warningDebouncer.reset();
    _errorDebouncer.reset();
    _instructionSet = false;
    // NOTE: _baseline intentionally preserved across reps.
  }
}
