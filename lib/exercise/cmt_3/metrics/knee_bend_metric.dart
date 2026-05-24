import 'cmt_3_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P3/P10: Theo dÃµi gÃ³c gá»‘i khi gáº­p ngÆ°á»i vá» trÆ°á»›c.
///
/// Máº·c dÃ¹ lÃ¢m sÃ ng cho phÃ©p gáº­p gá»‘i náº¿u khoeo chÃ¢n cá»©ng,
/// AI váº«n nháº¯c nháº¹ náº¿u gá»‘i cong quÃ¡ nhiá»u.
class KneeBendMetric extends Cmt3MetricBase {
  @override
  String get name => 'KneeBend';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _debouncer = Debouncer(requiredFrames: 4);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(Cmt3Context ctx) {
    final isActive = ctx.state == Cmt3State.p3_hastapaadasana ||
        ctx.state == Cmt3State.p10_hastapaadasana_return;
    if (!isActive) return;

    final isKneeBent = ctx.kneeAngle < Cmt3Config.KNEE_STRAIGHT_MIN;

    _debugData['kneeAngle'] = ctx.kneeAngle.toStringAsFixed(1);
    _debugData['isKneeBent'] = isKneeBent;

    final phase = ctx.state.name.toUpperCase();

    if (_debouncer.update(isKneeBent)) {
      ctx.resultIssues.feedback['Knee'] =
          'Cá»‘ gáº¯ng giá»¯ tháº³ng chÃ¢n Ä‘á»ƒ kÃ©o giÃ£n cÆ¡ khoeo';
      _logFault(phase, 'KneeBent',
          'Cá»‘ gáº¯ng giá»¯ tháº³ng chÃ¢n Ä‘á»ƒ kÃ©o giÃ£n cÆ¡ khoeo');
    } else {
      ctx.resultIssues.feedback['Knee'] = 'ChÃ¢n tá»‘t';
    }
  }

  void _logFault(String phase, String type, String msg) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: msg,
        affectsForm: false, // Nháº¯c nháº¹, khÃ´ng áº£nh hÆ°á»Ÿng form
        priority: SuryaVoicePriority.kneeBend,
        voiceMessage: 'Giá»¯ tháº³ng chÃ¢n',
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

