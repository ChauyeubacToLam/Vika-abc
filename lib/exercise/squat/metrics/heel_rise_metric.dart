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
  // ignore: constant_identifier_names
  static const double LIFT_THRESHOLD = 0.18;
}

class HeelRiseMetric extends SquatMetricBase {
  // Reuse the shared heel cue so post-rep playback matches the rest of the voice set.
  static const String _postRepVoiceCue = 'Giữ gót chân';

  @override
  String get name => 'HeelRise';

  @override
  String? get nameVi => 'Gót chân';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // 3 frames  ~0.1875s at 16fps — prevents false triggers from floor jitter
  final Debouncer _heelDebouncer = Debouncer(requiredFrames: 5);

  /// Prevent instruction spam — only set coaching once per rep.
  bool _instructionSet = false;
  double? _normalizedHeelLift;
  MetricStatus _status = MetricStatus.pass;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _normalizedHeelLift;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        faultAbove: HeelRiseConfig.LIFT_THRESHOLD,
      );

  @override
  MetricStatus get status => _status;

  @override
  void update(RepContext ctx) {
    double normalized = ctx.heelDistance / (ctx.scaleFactor ?? 1.0);
    _normalizedHeelLift = normalized;

    _debugData['heelNorm'] = normalized;
    _debugData['heelRaw'] = ctx.heelDistance;

    final phase = ctx.squatState.toString().split('.').last.toUpperCase();

    if (_heelDebouncer.update(normalized >= HeelRiseConfig.LIFT_THRESHOLD)) {
      _status = MetricStatus.fault;
      ctx.resultIssues.feedback['Heels'] = 'Heels lifting';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
            'standing', 'Heels', 'Heels lifting — try elevating heels');
        _instructionSet = true;
      }
      _logFault(phase, 'Heels lifting');
    } else {
      _status = MetricStatus.pass;
      ctx.resultIssues.feedback['Heels'] = 'Good Heels';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Heel')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Heel',
        message: message,
        voiceMessage: _postRepVoiceCue,
        affectsForm: true,
        priority: SquatFaultVoicePriority.heelRise,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _heelDebouncer.reset();
    _instructionSet = false;
    _normalizedHeelLift = null;
    _status = MetricStatus.pass;
  }
}
