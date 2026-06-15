import 'seated_forward_metric_base.dart';
import '../../../utils/debouncer.dart';

class AnkleDorsiflexionMetric extends SeatedForwardMetricBase {
  @override
  String get name => 'AnkleDorsi';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _ankleDebouncer = Debouncer(requiredFrames: 4);
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
    if (ctx.state == SeatedForwardState.setup) return;

    _debugData['ankleAngle'] = ctx.ankleAngle.toStringAsFixed(1);

    bool isPlantarFlexion =
        ctx.ankleAngle > SeatedForwardConfig.Ad_Fault_Ankle_Angle;

    if (_ankleDebouncer.update(isPlantarFlexion)) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Ankle'] = 'Bẻ gập mũi chân!';
      if (!_instructionSet) {
        ctx.resultIssues.addInstruction(
          ctx.state.name,
          'Ankle',
          'Mũi chân đang bị duỗi. Hãy hướng mũi chân lên trần nhà để kéo căng tối đa chuỗi cơ mặt sau.',
        );
        _instructionSet = true;
      }
      _logFault(ctx.state.name, 'Bẻ gập mũi chân hướng lên trần');
    } else {
      ctx.resultIssues.feedback['Ankle'] = 'Cổ chân chuẩn';
    }
  }

  void _logFault(String phase, String voiceMessage) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'AnklePlantar')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'AnklePlantar',
        message: 'Lỗi duỗi mũi chân',
        voiceMessage: voiceMessage,
        affectsForm: false,
        priority: SeatedForwardFaultVoicePriority.ankleDorsi,
      ));
    }
  }

  @override
  void reset() {
    super.reset();
    _instructionSet = false;
    _ankleDebouncer.reset();
    _isFaultingNow = false;
  }
}
