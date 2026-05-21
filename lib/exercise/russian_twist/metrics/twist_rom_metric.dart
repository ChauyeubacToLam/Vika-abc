import 'russian_metric_base.dart';
import '../russian_twist.dart';

class TwistRomMetric extends RussianMetricBase {

  @override
  void update(RussianRepContext ctx) {
    if (ctx.state == RussianTwistState.max_point) {
      bool passedHip = false;
      
      // In front camera, we need to check if midWrist crosses the leftHip or rightHip.
      // Assuming X increases to the right.
      if (ctx.direction == TwistDirection.left) {
        // If twisting left (user's left), their hands move to the left on the screen if NOT mirrored.
        // If mirrored, moving left -> moves left on screen. Actually it depends.
        // Let's just check if wrist is outside the hips boundary.
        // Hips boundary: min(leftHipX, rightHipX) to max(leftHipX, rightHipX).
        double minHip = ctx.leftHipX < ctx.rightHipX ? ctx.leftHipX : ctx.rightHipX;
        double maxHip = ctx.leftHipX > ctx.rightHipX ? ctx.leftHipX : ctx.rightHipX;

        // If wrist is less than minHip or greater than maxHip, it has crossed the body.
        if (ctx.midWristX < minHip || ctx.midWristX > maxHip) {
          passedHip = true;
        }
      } else if (ctx.direction == TwistDirection.right) {
        double minHip = ctx.leftHipX < ctx.rightHipX ? ctx.leftHipX : ctx.rightHipX;
        double maxHip = ctx.leftHipX > ctx.rightHipX ? ctx.leftHipX : ctx.rightHipX;

        if (ctx.midWristX < minHip || ctx.midWristX > maxHip) {
          passedHip = true;
        }
      }

      if (!passedHip) {
        addFault(
          FaultRecord(
            type: 'shallow_twist',
            message: 'Vặn chưa đủ sâu! Tay cần chạm tới giới hạn ngoài của hông.',
            affectsForm: false, // Medium
            phase: ctx.direction.name,
            priority: 4,
            voiceMessage: 'Vặn sâu hơn!',
          ),
        );
      }
    }
  }
}
