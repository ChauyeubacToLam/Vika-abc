import 'cossack_metric_base.dart';
import '../cossack_squat.dart';

class CossackKneeValgusMetric extends CossackMetricBase {
  @override
  void update(CossackRepContext ctx) {
    if (ctx.state == CossackState.standing ||
        ctx.workingLeg == WorkingLeg.none) {
      return;
    }

    // Check knee valgus using X coordinates.
    // In camera facing front, x increases from left to right on screen.
    // Left leg is on the right side of the screen (larger X).
    // Right leg is on the left side of the screen (smaller X).
    // But ML Kit Pose Detection returns mirrored coordinates if camera is front-facing (selfie).
    // Actually, usually x=0 is left, x=width is right of the image.
    // Wait, let's just check the relationship between knee and ankle.
    // If working leg is Left: knee should be further left (larger X if unmirrored, or smaller X if mirrored).
    // Let's use relative positioning: The knee should not move towards the center of the body relative to the ankle.
    // Center of body is between the two ankles. So for Left leg, knee X should be <= ankle X (or >= depending on mirroring).
    // A safer way: Check if knee is closer to the OTHER ankle than the working ankle is.
    // Or just use the Foot Index. The knee should be vertically aligned with the ankle/foot.
    // Let's calculate the horizontal distance from knee to ankle.

    // In ML Kit Front Camera:
    // User's Left is on screen Right (higher X). User's Right is on screen Left (lower X).
    // Working Leg Left (higher X): Valgus means knee collapses inward (towards center, lower X).
    // So if workingKneeX < workingAnkleX, it's collapsing inward.
    // Working Leg Right (lower X): Valgus means knee collapses inward (towards center, higher X).
    // So if workingKneeX > workingAnkleX, it's collapsing inward.

    bool isValgus = false;
    if (ctx.workingLeg == WorkingLeg.left) {
      // Left leg (screen right). Inward is smaller X.
      if (ctx.workingKneeX < ctx.workingAnkleX - 0.02) {
        // Add small threshold
        isValgus = true;
      }
    } else if (ctx.workingLeg == WorkingLeg.right) {
      // Right leg (screen left). Inward is larger X.
      if (ctx.workingKneeX > ctx.workingAnkleX + 0.02) {
        isValgus = true;
      }
    }

    debugData['kneeValgus'] = isValgus;

    if (isValgus) {
      addFault(
        FaultRecord(
          type: 'knee_valgus',
          message: 'Đẩy đầu gối ra ngoài! Không để gối chụm vào trong!',
          affectsForm: true,
          phase: ctx.state.name,
          priority: 1, // Critical
          voiceMessage: 'Đẩy đầu gối ra ngoài!',
        ),
      );
    }
  }
}
