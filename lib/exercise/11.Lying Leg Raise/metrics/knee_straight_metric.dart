import 'lying_leg_raise_metric_base.dart';
import '../../../utils/debouncer.dart';

class KneeStraightMetric extends LyingLegRaiseMetricBase {
  @override
  String get name => 'KneeStraight';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _bendDebouncer = Debouncer(requiredFrames: 4);

  double _minKneeAngle = 180.0;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.kneeAngle < _minKneeAngle) _minKneeAngle = ctx.kneeAngle;
    _debugData['minKneeAngle'] = _minKneeAngle.toStringAsFixed(1);

    if (ctx.state == LyingLegRaiseState.raising || ctx.state == LyingLegRaiseState.lowering) {
      bool isBending = ctx.kneeAngle < LegRaiseConfig.KNEE_STRAIGHT_SETUP - 10; // Chấp nhận co nhẹ nhưng ko được gập
      
      if (_bendDebouncer.update(isBending)) {
        ctx.resultIssues.feedback['Knee'] = 'Gập gối (Giảm độ khó)';
        if (!_faults.any((f) => f.type == 'KneeBending')) {
          _faults.add(FaultRecord(
            phase: ctx.state.name.toUpperCase(), type: 'KneeBending', message: 'Co đầu gối',
            affectsForm: false, priority: LegRaiseVoicePriority.kneeStraight, 
            voiceMessage: 'Cố gắng khóa thẳng đầu gối để dồn hết áp lực vào cơ bụng dưới.'
          ));
        }
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _bendDebouncer.reset();
    _minKneeAngle = 180.0;
  }
}