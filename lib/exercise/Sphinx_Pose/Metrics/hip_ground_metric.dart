import 'sphinx_metric_base.dart';
import '../../../utils/debouncer.dart';

class HipGroundMetric extends SphinxMetricBase {
  @override
  String get name => 'HipGround';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  final Debouncer _hipLiftDebouncer = Debouncer(requiredFrames: 3);
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SphinxContext ctx) {
    if (ctx.state != SphinxState.isometricHold && ctx.state != SphinxState.ascending) return;

    double rawLift = ctx.ankleY - ctx.hipY; 
    double normalizedLift = rawLift / (ctx.scaleFactor <= 0 ? 1 : ctx.scaleFactor);
    
    _debugData['hipLiftNorm'] = normalizedLift.toStringAsFixed(3);

    bool isLifting = normalizedLift > SphinxConfig.Ad_Hip_Ground_Tol;

    if (_hipLiftDebouncer.update(isLifting)) {
      ctx.resultIssues.feedback['Hip'] = 'Ấn hông sát sàn!';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction('isometricHold', 'Hip', 'Hông đang bị nhấc cao, hãy ấn chặt xương chậu xuống sàn.');
        _instructionSet = true;
      }
      _logFault(ctx.state.name, 'Nhấc hông khỏi sàn');
    } else {
      ctx.resultIssues.feedback['Hip'] = 'Tốt';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Hip')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Hip',
        message: message,
        voiceMessage: 'Ấn chặt hông xuống sàn',
        affectsForm: true,
        priority: SphinxFaultVoicePriority.hipLift,
      ));
    }
  }

  // [Fix Bug 4]: Reset _instructionSet (và các debouncer) về mặc định
  @override
  void reset() {
    super.reset();
    _instructionSet = false;
    _hipLiftDebouncer.reset();
  }
}