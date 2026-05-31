// ignore_for_file: curly_braces_in_flow_control_structures
import 'cobra_metric_base.dart';
import '../cobra.dart';
import '../../../utils/debouncer.dart';

/// MET-5: Pelvic Grounding / Hip Lift Detector
/// Uses baseline-delta method: hipLiftNorm = (baselineHipY - Hip.y) / trunkLength.
/// MANDATORY confidence gate: skip when hip confidence < 0.4.
/// Fail-open policy: no feedback > false positives.
class CobraPelvicMetric extends CobraMetricBase {
  @override
  String get name => 'PelvicGrounding';

  // Beginner thresholds (normalized)
  static const double _goodMax = 0.12;
  static const double _errorMin = 0.18;
  static const double _minHipConfidence = 0.4;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final StickyDebouncer _hipLiftDebouncer = StickyDebouncer(requiredFrames: 10);
  final StickyDebouncer _errorDebouncer = StickyDebouncer(requiredFrames: 15);

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.state == CobraState.setup) return;
    if (ctx.hip == null) return;

    // MANDATORY confidence gate
    if (ctx.hip!.likelihood < _minHipConfidence) {
      _debugData['hipLift'] = 'low_conf';
      return; // Fail-open: no feedback
    }

    // Need baseline from calibration
    if (ctx.baselineHipY == null || ctx.baselineTrunkLength == null) {
      _debugData['hipLift'] = 'no_baseline';
      return;
    }

    final trunkLength = ctx.baselineTrunkLength!;
    if (trunkLength < 1.0) return;

    // baseline-delta method (Perplexity recommendation)
    // Note: in screen coords, Y increases downward.
    // If hip lifts UP, hip.y DECREASES, so (baseline - current) is POSITIVE.
    final hipLiftNorm = (ctx.baselineHipY! - ctx.hip!.y) / trunkLength;

    _debugData['hipLift'] = hipLiftNorm.toStringAsFixed(3);

    final phase = ctx.state.name;

    // Error: significant lift (>=0.18)
    if (_errorDebouncer.update(hipLiftNorm >= _errorMin)) {
      ctx.resultIssues.feedback['Hips'] = '⚠️ Hông nâng quá cao!';
      ctx.resultIssues.addInstruction(
        'holding',
        'hipLifted',
        'Giữ hông sát sàn. Đừng nâng quá cao.',
      );
      _logFault(phase, 'Hip significantly lifted', 'HipLift');
    }
    // Warning: moderate lift (>=0.12)
    else if (_hipLiftDebouncer.update(hipLiftNorm >= _goodMax)) {
      ctx.resultIssues.feedback['Hips'] = 'Ép hông xuống sàn hơn';
    }
    // Good: grounded
    else {
      ctx.resultIssues.feedback['Hips'] = 'Hông tốt ✓';
    }
  }

  void _logFault(String phase, String message, String type) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _hipLiftDebouncer.reset();
    _errorDebouncer.reset();
  }
}
