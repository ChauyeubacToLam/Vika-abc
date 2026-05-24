import 'cmt_8_metric_base.dart';
import '../../../utils/debouncer.dart';

/// Metric P4/P9: Lá»±c cáº¯t Ä‘áº§u gá»‘i chÃ¢n trÆ°á»›c trong tÆ° tháº¿ Ká»µ sÄ©.
///
/// Náº¿u Knee X vÆ°á»£t quÃ¡ xa FOOT_INDEX X â†’ Ä‘áº§u gá»‘i bá»‹ Ä‘áº©y quÃ¡ trÆ°á»›c,
/// gÃ¢y Ã¡p lá»±c lÃªn dÃ¢y cháº±ng Ä‘áº§u gá»‘i.
class LungeKneeShearMetric extends Cmt8MetricBase {
  @override
  String get name => 'LungeKneeShear';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _debouncer = Debouncer(requiredFrames: 3);

  // LÆ°u gÃ³c gá»‘i á»Ÿ P4 vÃ  P9 Ä‘á»ƒ so sÃ¡nh Ä‘á»‘i xá»©ng
  double? lungeKneeAngleP4;
  double? lungeKneeAngleP9;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(Cmt8Context ctx) {
    final isActive = ctx.state == Cmt8State.p4_ashwa_sanchalanasana ||
        ctx.state == Cmt8State.p9_ashwa_return;
    if (!isActive) return;

    // Khoáº£ng cÃ¡ch normalized: knee vÆ°á»£t trÆ°á»›c foot_index
    final sf = ctx.scaleFactor == 0 ? 1.0 : ctx.scaleFactor;
    final kneeOverFoot = (ctx.kneeX - ctx.footIndexX).abs() / sf;

    final isShearing = kneeOverFoot > Cmt8Config.KNEE_OVER_FOOT_TOLERANCE;

    // Ghi láº¡i gÃ³c gá»‘i cho symmetry tracking
    if (ctx.state == Cmt8State.p4_ashwa_sanchalanasana) {
      lungeKneeAngleP4 = ctx.kneeAngle;
    } else {
      lungeKneeAngleP9 = ctx.kneeAngle;
    }

    _debugData['kneeOverFootNorm'] = kneeOverFoot.toStringAsFixed(2);
    _debugData['kneeAngle'] = ctx.kneeAngle.toStringAsFixed(1);
    _debugData['isShearing'] = isShearing;

    final phase = ctx.state.name.toUpperCase();

    if (_debouncer.update(isShearing)) {
      ctx.resultIssues.feedback['Lunge'] =
          'BÆ°á»›c chÃ¢n sau dÃ i ra, giá»¯ Ä‘áº§u gá»‘i tháº³ng gÃ³c vá»›i máº¯t cÃ¡!';
      _logFault(phase, 'KneeShear',
          'BÆ°á»›c chÃ¢n sau dÃ i ra, giá»¯ Ä‘áº§u gá»‘i tháº³ng gÃ³c vá»›i máº¯t cÃ¡!');
    } else {
      // Kiá»ƒm tra gÃ³c gá»‘i cÃ³ trong khoáº£ng chuáº©n khÃ´ng
      if (ctx.kneeAngle >= Cmt8Config.LUNGE_KNEE_ANGLE_RANGE[0] &&
          ctx.kneeAngle <= Cmt8Config.LUNGE_KNEE_ANGLE_RANGE[1]) {
        ctx.resultIssues.feedback['Lunge'] = 'Ká»µ sÄ© chuáº©n';
      } else {
        ctx.resultIssues.feedback['Lunge'] = 'Äiá»u chá»‰nh gÃ³c gá»‘i';
      }
    }
  }

  void _logFault(String phase, String type, String msg) {
    if (!_faults.any((f) => f.type == type)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: type,
        message: msg,
        affectsForm: true,
        priority: SuryaVoicePriority.lungeKneeShear,
        voiceMessage: 'Giá»¯ Ä‘áº§u gá»‘i tháº³ng gÃ³c',
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _debouncer.reset();
    // KhÃ´ng reset lungeKneeAngleP4/P9 vÃ¬ cáº§n cho symmetry cuá»‘i rep
  }
}

