import 'seated_forward_metric_base.dart';
import '../../../utils/debouncer.dart';

class SpinalAlignmentMetric extends SeatedForwardMetricBase {
  @override
  String get name => 'SpinalAlignment';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _spineRoundDebouncer = Debouncer(requiredFrames: 4);
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SeatedForwardContext ctx) {
    if (ctx.state == SeatedForwardState.setup) return;

    _debugData['spineAngle'] = ctx.spineAngle.toStringAsFixed(1);
    
    bool isRounding = ctx.spineAngle < SeatedForwardConfig.As_Fault_Spine_Angle;

    if (_spineRoundDebouncer.update(isRounding)) {
      ctx.resultIssues.feedback['Spine'] = 'Thẳng lưng lên!';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          ctx.state.name,
          'Spine',
          'Lưng đang bị gù. Hãy kê cao mông (ngồi lên đệm), ưu tiên co nhẹ gối để bụng chạm đùi thay vì cố vươn tay chạm chân.',
        );
        _instructionSet = true;
      }
      _logFault(ctx.state.name, 'Ưỡn ngực, vươn dài lưng ra');
    } else {
      ctx.resultIssues.feedback['Spine'] = 'Lưng thẳng tốt';
    }
  }

  void _logFault(String phase, String voiceMessage) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'SpineRound')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'SpineRound',
        message: 'Lỗi gù lưng',
        voiceMessage: voiceMessage,
        affectsForm: true, 
        priority: SeatedForwardFaultVoicePriority.spineRound,
      ));
    }
  }

  @override
  void reset() {
    super.reset();
    _instructionSet = false;
    _spineRoundDebouncer.reset();
  }
}