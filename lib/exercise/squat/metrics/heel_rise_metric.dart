/* =========================================================================
   Metric 3: Heel Rise Detection
   Priority: IMPORTANT — Ship Week 2-4
   
   Detects whether heels lift off ground during the squat.
   Strong diagnostic for ankle mobility limitation.
   
   IMPORTANT: This is INFORMATIONAL ONLY — does NOT mark correctForm = false.
   Vietnamese desk workers + motorbike commuters have high prevalence of
   tight ankles. Frame as a mobility finding, not an error.
   ========================================================================= */

import 'squat_metric_base.dart';
import '../../../utils/debouncer.dart';

class HeelRiseConfig {
  /// Heel lift threshold normalized to back length (shoulder-to-hip).
  /// 0.15 = "If heel lifts more than 10% of back length."
  // ignore: constant_identifier_names
  static const double LIFT_THRESHOLD = 0.1;
}

class HeelRiseMetric extends SquatMetricBase {
  @override
  String get name => 'HeelRise';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // 3 frames  ~0.1875s at 16fps — prevents false triggers from floor jitter
  final Debouncer _heelDebouncer = Debouncer(requiredFrames: 3);

  /// Prevent instruction spam — only set coaching once per rep.
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    double normalized = ctx.heelDistance / (ctx.scaleFactor ?? 1.0);

    _debugData['heelNorm'] = normalized.toStringAsFixed(3);
    _debugData['heelRaw'] = ctx.heelDistance.toStringAsFixed(2);

    final phase = ctx.squatState.toString().split('.').last.toUpperCase();

    if (_heelDebouncer.update(normalized >= HeelRiseConfig.LIFT_THRESHOLD)) {
      ctx.resultIssues.feedback['Feet'] = 'Heels lifting';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
            'standing', 'Feet', 'Heels lifting — try elevating heels');
        _instructionSet = true;
      }
      _logFault(phase, 'Heels lifting');
    } else {
      ctx.resultIssues.feedback['Feet'] = 'Good Heels';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Feet')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Feet',
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _heelDebouncer.reset();
    _instructionSet = false;
  }
}
