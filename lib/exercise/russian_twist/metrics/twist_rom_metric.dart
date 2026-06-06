import 'russian_metric_base.dart';
import '../russian_twist.dart';

class TwistRomMetric extends RussianMetricBase {
  @override
  void update(RussianRepContext ctx) {
    if (ctx.state == RussianTwistState.max_point) {
      bool sufficientRom = false;

      // We check if the wrist moved far enough relative to the knee-hip distance.
      // kneeHipDx is always positive.
      // wristHipDx is 0 at the hip, and equal to kneeHipDx at the knee.

      if (ctx.direction == TwistDirection.forward) {
        // Twisting towards the knees. Hands should reach past ~60% of the way to the knees.
        if (ctx.wristHipDx >=
            ctx.kneeHipDx * RussianTwistConfig.FORWARD_ROM_RATIO) {
          sufficientRom = true;
        }
      } else if (ctx.direction == TwistDirection.backward) {
        // Twisting towards the back. Hands should reach close to or behind the hips.
        // Less than 20% of the way to the knees.
        if (ctx.wristHipDx <=
            ctx.kneeHipDx * RussianTwistConfig.BACKWARD_ROM_RATIO) {
          sufficientRom = true;
        }
      }

      if (!sufficientRom) {
        addFault(
          FaultRecord(
            type: 'shallow_twist',
            message:
                'Vặn chưa đủ sâu! Tay cần di chuyển dứt khoát qua hai bên hông.',
            affectsForm:
                true, // Must be true so rep is failed/ignored as per requirements
            phase: ctx.direction.name,
            priority: 4,
            voiceMessage: 'Vặn sâu hơn!',
          ),
        );
      }
    }
  }
}
