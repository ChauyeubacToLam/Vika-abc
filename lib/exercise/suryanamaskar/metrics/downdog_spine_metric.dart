import 'surya_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P5/P8: Gù lưng / Sập vai trong tư thế Chó cúi mặt.
///
/// Góc Wrist-Shoulder-Hip phải ~170-180° (cánh tay thẳng hàng với thân).
/// Nếu vai gập tới trước (góc giảm) → gù lưng, sập vai.
class DowndogSpineMetric extends SuryaMetricBase {
  @override
  String get name => 'DowndogSpine';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _debouncer = Debouncer(requiredFrames: 3);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SuryaContext ctx) {
    final isActive = ctx.state == SuryaState.p5_parvatasana ||
        ctx.state == SuryaState.p8_parvatasana_return;
    if (!isActive) return;

    final armAngle = ctx.armShoulderAngle;
    final isSpineCollapsed =
        armAngle < SuryaConfig.V_SHAPE_ARM_ANGLE_RANGE[0];

    _debugData['armShoulderAngle'] = armAngle.toStringAsFixed(1);
    _debugData['isSpineCollapsed'] = isSpineCollapsed;

    final phase = ctx.state.name.toUpperCase();

    if (_debouncer.update(isSpineCollapsed)) {
      ctx.resultIssues.feedback['Spine'] =
          'Đẩy mạnh tay, ép vai xuống, giữ lưng thẳng!';
      _logFault(phase, 'DowndogSpineCollapse',
          'Đẩy mạnh tay, ép vai xuống, giữ lưng thẳng!');
    } else {
      ctx.resultIssues.feedback['Spine'] = 'Chó cúi mặt chuẩn';
    }
  }

  void _logFault(String phase, String type, String msg) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: msg,
        affectsForm: true,
        priority: SuryaVoicePriority.downdogSpine,
        voiceMessage: 'Ép vai xuống, giữ lưng thẳng',
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _debouncer.reset();
  }
}
