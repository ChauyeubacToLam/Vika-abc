import 'cossack_metric_base.dart';
import '../cossack_squat.dart';

class CossackKneeValgusMetric extends CossackMetricBase {
  static const double _valgusNormThreshold = 0.14;

  @override
  void update(CossackRepContext ctx) {
    if (ctx.state == CossackState.standing ||
        ctx.workingLeg == WorkingLeg.none ||
        ctx.scaleFactor <= 1e-6) {
      return;
    }

    final signedKneeAnkleDx =
        (ctx.workingKneeX - ctx.workingAnkleX) / ctx.scaleFactor;
    var inwardDriftNorm = 0.0;
    if (ctx.workingLeg == WorkingLeg.left) {
      inwardDriftNorm = -signedKneeAnkleDx;
    } else if (ctx.workingLeg == WorkingLeg.right) {
      inwardDriftNorm = signedKneeAnkleDx;
    }

    final isValgus = inwardDriftNorm > _valgusNormThreshold;
    debugData['kneeValgus'] = isValgus;
    debugData['kneeValgusNorm'] = inwardDriftNorm.toStringAsFixed(2);

    if (isValgus) {
      addFault(
        FaultRecord(
          type: 'knee_valgus',
          message: 'Đẩy đầu gối ra ngoài, đừng để gối chụm vào trong.',
          affectsForm: true,
          phase: ctx.state.name,
          priority: 1,
          voiceMessage: 'Đẩy đầu gối ra ngoài.',
        ),
      );
    }
  }
}
