import 'sphinx_metric_base.dart';
import '../../../utils/debouncer.dart';

class ElbowAngleMetric extends SphinxMetricBase {
  @override
  String get name => 'ElbowAngle';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _straightArmDebouncer = Debouncer(requiredFrames: 4);
  final Debouncer _forearmDebouncer = Debouncer(requiredFrames: 4);
  final Debouncer _upperArmDebouncer = Debouncer(requiredFrames: 4);
  bool _instructionSet = false;
  bool _isFaultingNow = false;
  FaultRecord? _currentFault;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;
  FaultRecord? get currentFault => _currentFault;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SphinxContext ctx) {
    _isFaultingNow = false;
    _currentFault = null;
    if (ctx.state != SphinxState.isometricHold &&
        ctx.state != SphinxState.ascending) {
      return;
    }

    _debugData['elbowAngle'] = ctx.elbowAngle.toStringAsFixed(1);

    // [Fix Bug 3]: Tách logic hiển thị cho phase ascending (chỉ hướng dẫn, không phạt lỗi)
    if (ctx.state == SphinxState.ascending) {
      ctx.resultIssues.feedback['Arm'] =
          ctx.elbowAngle > 100 ? 'Tiếp tục gập tay' : 'Tốt';
      return;
    }

    // Phase isometricHold: Bắt lỗi đẩy thẳng tay
    if (_straightArmDebouncer
        .update(ctx.elbowAngle > SphinxConfig.Ab_Elbow_Hold_Angle[1])) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Arm'] = 'Gập khuỷu tay lại!';
      if (!_instructionSet) {
        // Legacy UI instruction copy: Đang bị sai thành Rắn hổ mang. Hạ cẳng tay chạm sàn.
        _instructionSet = true;
      }
      _currentFault = _logFault(
        ctx.state.name,
        'StraightArm',
        'Lỗi đẩy thẳng tay',
        'Gập cùi chỏ lại',
      );
    } else if (_forearmDebouncer
        .update(ctx.forearmAngle > SphinxConfig.Aj_Forearm_Horiz_Tol)) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Arm'] = 'Hạ cẳng tay xuống sàn!';
      _currentFault = _logFault(
        ctx.state.name,
        'Forearm',
        'Cẳng tay không song song sàn',
        'Hạ cẳng tay xuống sàn',
      );
    } else if (_upperArmDebouncer
        .update(ctx.upperArmAngle < SphinxConfig.Ak_UpperArm_Vert_Tol)) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Arm'] = 'Cánh tay phải vuông góc!';
      _currentFault = _logFault(
        ctx.state.name,
        'UpperArm',
        'Cánh tay không vuông góc sàn',
        'Chống tay vuông góc với sàn',
      );
    } else if (ctx.elbowAngle < SphinxConfig.Ab_Elbow_Hold_Angle[0]) {
      ctx.resultIssues.feedback['Arm'] = 'Đẩy ngực lên!';
    } else {
      ctx.resultIssues.feedback['Arm'] = 'Tay chuẩn';
    }
  }

  FaultRecord _logFault(
    String phase,
    String type,
    String message,
    String voiceMsg,
  ) {
    for (final fault in _faults) {
      if (fault.phase == phase && fault.type == type) return fault;
    }
    final fault = FaultRecord(
      phase: phase,
      type: type,
      message: message,
      voiceMessage: voiceMsg,
      affectsForm: true,
      priority: SphinxFaultVoicePriority.straightArm,
    );
    _faults.add(fault);
    return fault;
  }

  // [Fix Bug 4]: Reset _instructionSet (và các debouncer) về mặc định
  @override
  void reset() {
    super.reset();
    _instructionSet = false;
    _straightArmDebouncer.reset();
    _forearmDebouncer.reset();
    _upperArmDebouncer.reset();
    _isFaultingNow = false;
    _currentFault = null;
  }
}
