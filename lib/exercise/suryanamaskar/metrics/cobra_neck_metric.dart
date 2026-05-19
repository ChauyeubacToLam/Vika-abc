import 'surya_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P7: Rụt cổ / Gãy thắt lưng trong tư thế Rắn hổ mang.
///
/// Khoảng cách trục Y giữa Tai (Ear) và Vai (Shoulder) phải đủ lớn
/// (cổ vươn dài). Nếu Vai bị co rút sát Tai → rụt cổ.
class CobraNeckMetric extends SuryaMetricBase {
  @override
  String get name => 'CobraNeck';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _debouncer = Debouncer(requiredFrames: 3);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SuryaContext ctx) {
    if (ctx.state != SuryaState.p7_bhujangasana) return;

    final sf = ctx.scaleFactor == 0 ? 1.0 : ctx.scaleFactor;
    final earShoulderRatio = ctx.earShoulderDist / sf;

    final isNeckRetracted =
        earShoulderRatio < SuryaConfig.COBRA_EAR_SHOULDER_MIN_RATIO;

    _debugData['earShoulderDist'] = ctx.earShoulderDist.toStringAsFixed(1);
    _debugData['earShoulderRatio'] = earShoulderRatio.toStringAsFixed(2);
    _debugData['isNeckRetracted'] = isNeckRetracted;

    if (_debouncer.update(isNeckRetracted)) {
      ctx.resultIssues.feedback['Neck'] =
          'Hạ vai xuống, vươn dài cổ lên!';
      _logFault('P7_BHUJANGASANA', 'NeckRetracted',
          'Hạ vai xuống, vươn dài cổ lên!');
    } else {
      ctx.resultIssues.feedback['Neck'] = 'Cổ vươn dài tốt';
    }
  }

  void _logFault(String phase, String type, String msg) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: msg,
        affectsForm: true,
        priority: SuryaVoicePriority.cobraNeck,
        voiceMessage: 'Hạ vai, vươn cổ lên',
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
