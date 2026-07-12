import 'plank_up_down_metric_base.dart';
import '../../../utils/debouncer.dart';

class TrunkAlignmentMetric extends PlankMetricBase {
  @override
  String get name => 'Trunk Alignment';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _sagDebouncer = Debouncer(requiredFrames: 3);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(PlankRepContext ctx) {
    bool isSagging = ctx.bodyAngle < PlankConfig.BODY_ALIGNMENT_SAG_THRESHOLD;

    if (_sagDebouncer.update(isSagging)) {
      ctx.resultIssues.feedback['Trunk'] = 'Sụt hông! Gồng chặt cơ bụng';
      if (!_faults.any((f) => f.type == 'trunk')) {
        _faults.add(FaultRecord(
          phase: ctx.currentState.name,
          type: 'trunk',
          message: 'Sụt hông, mất liên kết Core',
          affectsForm: true,
          voiceMessage: 'Sụt hông! Gồng chặt cơ bụng, đừng để lưng bị võng!',
          priority: PlankFaultVoicePriority.trunkSagging,
        ));
      }
    } else {
      ctx.resultIssues.feedback['Trunk'] = 'Core ổn định';
    }
  }

  @override
  void reset() {
    _faults.clear();
    _sagDebouncer.reset();
  }
}
