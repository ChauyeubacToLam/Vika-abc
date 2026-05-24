import 'cmt_11_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P5/P8: GÃ¹ lÆ°ng / Sáº­p vai trong tÆ° tháº¿ ChÃ³ cÃºi máº·t.
///
/// GÃ³c Wrist-Shoulder-Hip pháº£i ~170-180Â° (cÃ¡nh tay tháº³ng hÃ ng vá»›i thÃ¢n).
/// Náº¿u vai gáº­p tá»›i trÆ°á»›c (gÃ³c giáº£m) â†’ gÃ¹ lÆ°ng, sáº­p vai.
class DowndogSpineMetric extends Cmt11MetricBase {
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
  void update(Cmt11Context ctx) {
    final isActive = ctx.state == Cmt11State.p5_parvatasana ||
        ctx.state == Cmt11State.p8_parvatasana_return;
    if (!isActive) return;

    final armAngle = ctx.armShoulderAngle;
    final isSpineCollapsed =
        armAngle < Cmt11Config.V_SHAPE_ARM_ANGLE_RANGE[0];

    _debugData['armShoulderAngle'] = armAngle.toStringAsFixed(1);
    _debugData['isSpineCollapsed'] = isSpineCollapsed;

    final phase = ctx.state.name.toUpperCase();

    if (_debouncer.update(isSpineCollapsed)) {
      ctx.resultIssues.feedback['Spine'] =
          'Äáº©y máº¡nh tay, Ã©p vai xuá»‘ng, giá»¯ lÆ°ng tháº³ng!';
      _logFault(phase, 'DowndogSpineCollapse',
          'Äáº©y máº¡nh tay, Ã©p vai xuá»‘ng, giá»¯ lÆ°ng tháº³ng!');
    } else {
      ctx.resultIssues.feedback['Spine'] = 'ChÃ³ cÃºi máº·t chuáº©n';
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
        voiceMessage: 'Ã‰p vai xuá»‘ng, giá»¯ lÆ°ng tháº³ng',
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

