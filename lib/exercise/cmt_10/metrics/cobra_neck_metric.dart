import 'cmt_10_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P7: Rá»¥t cá»• / GÃ£y tháº¯t lÆ°ng trong tÆ° tháº¿ Ráº¯n há»• mang.
///
/// Khoáº£ng cÃ¡ch trá»¥c Y giá»¯a Tai (Ear) vÃ  Vai (Shoulder) pháº£i Ä‘á»§ lá»›n
/// (cá»• vÆ°Æ¡n dÃ i). Náº¿u Vai bá»‹ co rÃºt sÃ¡t Tai â†’ rá»¥t cá»•.
class CobraNeckMetric extends Cmt10MetricBase {
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
  void update(Cmt10Context ctx) {
    if (ctx.state != Cmt10State.p7_bhujangasana) return;

    final sf = ctx.scaleFactor == 0 ? 1.0 : ctx.scaleFactor;
    final earShoulderRatio = ctx.earShoulderDist / sf;

    final isNeckRetracted =
        earShoulderRatio < Cmt10Config.COBRA_EAR_SHOULDER_MIN_RATIO;

    _debugData['earShoulderDist'] = ctx.earShoulderDist.toStringAsFixed(1);
    _debugData['earShoulderRatio'] = earShoulderRatio.toStringAsFixed(2);
    _debugData['isNeckRetracted'] = isNeckRetracted;

    if (_debouncer.update(isNeckRetracted)) {
      ctx.resultIssues.feedback['Neck'] =
          'Háº¡ vai xuá»‘ng, vÆ°Æ¡n dÃ i cá»• lÃªn!';
      _logFault('P7_BHUJANGASANA', 'NeckRetracted',
          'Háº¡ vai xuá»‘ng, vÆ°Æ¡n dÃ i cá»• lÃªn!');
    } else {
      ctx.resultIssues.feedback['Neck'] = 'Cá»• vÆ°Æ¡n dÃ i tá»‘t';
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
        voiceMessage: 'Háº¡ vai, vÆ°Æ¡n cá»• lÃªn',
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

