import 'seated_forward_metric_base.dart';
import '../../../utils/debouncer.dart';

class KneeExtensionMetric extends SeatedForwardMetricBase {
  @override
  String get name => 'KneeExtension';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _kneeBendDebouncer = Debouncer(requiredFrames: 5);
  bool _instructionSet = false;
  bool _isFaultingNow = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SeatedForwardContext ctx) {
    _isFaultingNow = false;
    if (ctx.state == SeatedForwardState.setup ||
        ctx.state == SeatedForwardState.ascending) {
      return;
    }

    _debugData['kneeAngle'] = ctx.kneeAngle.toStringAsFixed(1);

    bool isKneeBent = ctx.kneeAngle < SeatedForwardConfig.Ak_Fault_Knee_Angle;

    if (_kneeBendDebouncer.update(isKneeBent)) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Knee'] = 'Thẳng gối ra!';
      if (!_instructionSet) {
        // Legacy UI instruction copy: Gối co quá nhiều. Hãy gập người từ hông, giữ lưng thẳng và ép nhẹ gối xuống.
        _instructionSet = true;
      }
      _logFault(ctx.state.name, 'Ép thẳng đầu gối xuống');
    } else {
      ctx.resultIssues.feedback['Knee'] = 'Gối chuẩn';
    }
  }

  void _logFault(String phase, String voiceMessage) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'KneeBent')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'KneeBent',
        message: 'Lỗi co gối',
        voiceMessage: voiceMessage,
        affectsForm: true,
        priority: SeatedForwardFaultVoicePriority.kneeBent,
      ));
    }
  }

  @override
  void reset() {
    super.reset();
    _instructionSet = false;
    _kneeBendDebouncer.reset();
    _isFaultingNow = false;
  }
}
