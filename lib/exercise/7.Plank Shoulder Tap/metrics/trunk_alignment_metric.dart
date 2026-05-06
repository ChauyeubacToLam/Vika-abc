import 'plank_shoulder_tap_metric_base.dart';
import '../../../utils/debouncer.dart';

class TrunkAlignmentMetric extends PlankTapMetricBase {
  @override
  String get name => 'TrunkAlignment';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _sagDebouncer = Debouncer(requiredFrames: 4);

  double? _minTrunkAngle;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (_minTrunkAngle == null || ctx.trunkAngle < _minTrunkAngle!) {
      _minTrunkAngle = ctx.trunkAngle;
    }

    _debugData['trunkAngle'] = ctx.trunkAngle.toStringAsFixed(1);

    bool isSagging = ctx.trunkAngle < PlankTapConfig.TRUNK_SAG_THRESHOLD;

    if (_sagDebouncer.update(isSagging)) {
      ctx.resultIssues.feedback['Spine'] = 'Võng lưng/Chổng mông!';
      if (!_faults.any((f) => f.type == 'TrunkSag')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name.toUpperCase(), type: 'TrunkSag', message: 'Mất trục lưng thẳng',
          affectsForm: true, priority: PlankTapVoicePriority.trunkAlignment, voiceMessage: 'Thẳng lưng lên, siết mông và cơ lõi'
        ));
      }
    } else {
      ctx.resultIssues.feedback['Spine'] = 'Lưng thẳng';
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _sagDebouncer.reset();
    _minTrunkAngle = null;
  }
}