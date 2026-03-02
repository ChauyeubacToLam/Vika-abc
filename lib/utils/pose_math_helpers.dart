import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../exercise/exercise_base.dart';

/* ---------------------------------------------------------------------------
  PART 1: JOINT FLEXION (0 - 180 degrees)
  ---------------------------------------------------------------------------
  Measures the angle between three landmarks (e.g., Hip -> Knee -> Ankle).
  Logic adapted directly from Google ML Kit documentation.
*/
double calculateAngleNormalized(
    {required PoseLandmark firstPoint,
    required PoseLandmark midPoint,
    required PoseLandmark lastPoint}) {
  // 1. Calculate the difference of angles in radians
  // Logic: atan2(last) - atan2(first)
  double radians =
      math.atan2(lastPoint.y - midPoint.y, lastPoint.x - midPoint.x) -
          math.atan2(firstPoint.y - midPoint.y, firstPoint.x - midPoint.x);

  // 2. Convert to degrees
  double degrees = radians * (180.0 / math.pi);

  // 3. Absolute value (Angle should never be negative)
  degrees = degrees.abs();

  // 4. Normalize to acute representation (always <= 180)
  if (degrees > 180.0) {
    degrees = 360.0 - degrees;
  }

  return degrees;
}

double calculateAngle(
    {required PoseLandmark firstPoint,
    required PoseLandmark midPoint,
    required PoseLandmark lastPoint}) {
  // 1. Calculate the difference of angles in radians
  // Logic: atan2(last) - atan2(first)
  double radians =
      math.atan2(lastPoint.y - midPoint.y, lastPoint.x - midPoint.x) -
          math.atan2(firstPoint.y - midPoint.y, firstPoint.x - midPoint.x);

  // 2. Convert to degrees
  double degrees = radians * (180.0 / math.pi);

  // 3. Absolute value (Angle should never be negative)
  degrees = degrees.abs();

  return degrees;
}

/* ---------------------------------------------------------------------------
  PART 2: VERTICAL "CLOCK" ANGLE (0 - 360 degrees)
  ---------------------------------------------------------------------------
  Measures position relative to GRAVITY (Vertical axis).
  Used for checking back posture (leaning forward/backward).
  
  COORDINATE MAP (Clockwise):
       0 (UP / Vertical)
       |
  270 -+- 90 (Right)
       |
      180 (Down)
*/
double calculateVerticalAngle(
    {required PoseLandmark pivot, required PoseLandmark point}) {
  // 1. Calculate raw angle from Pivot (Hip) to Point (Shoulder/Knee)
  // atan2 returns: 0=Right, 90=Down, -90=Up, 180=Left
  double dy = point.y - pivot.y;
  double dx = point.x - pivot.x;

  double radians = math.atan2(dy, dx);
  double degrees = radians * (180.0 / math.pi);

  // 2. Rotate Coordinates so 0 is UP
  // Standard atan2 says Up is -90. We add 90 so (-90 + 90) = 0.
  double clockAngle = degrees + 90.0;

  // 3. Normalize to 0-360 range
  // Handles negative results (e.g., -10 becomes 350)
  if (clockAngle < 0) {
    clockAngle += 360.0;
  }

  // Ensure result is within 0-360
  clockAngle = clockAngle % 360.0;

  return clockAngle;
}

double calculateDistance(var point1, var point2) {
  double dx = point2.x - point1.x;
  double dy = point2.y - point1.y;
  return math.sqrt(dx * dx + dy * dy);
}

/* =========================================================================
   HELPER: Clock Angle to Trunk Lean Conversion
   Converts the 0-360° clock angle into degrees-from-vertical (0-90°)
   - negative values for backward lean
   - positive values for forward lean
   ========================================================================= */
// Return: POSITIVE = forward lean, NEGATIVE = backward lean, 0 = vertical
double convertClockAngleToTrunkLean(double clockAngle, CameraFacing facing) {
  if (facing == CameraFacing.left) {
    // LEFT-FACING VIEW:
    // 270-360° = forward lean (shoulder ahead of hip)
    // 0-90° = backward lean (shoulder behind hip)

    if (clockAngle >= 270) {
      // Forward lean: 330° → +30°
      return (360 - clockAngle).toDouble();
    } else if (clockAngle <= 90) {
      // Backward lean: 30° → -30°
      return -clockAngle;
    } else {
      // Extreme angles (90-270°) - invalid
      return clockAngle > 180 ? 90.0 : -90.0;
    }
  } else if (facing == CameraFacing.right) {
    // RIGHT-FACING VIEW (mirror):
    // 0-90° = forward lean
    // 270-360° = backward lean

    if (clockAngle <= 90) {
      // Forward lean: 30° → +30°
      return clockAngle;
    } else if (clockAngle >= 270) {
      // Backward lean: 330° → -30°
      return -(360 - clockAngle);
    } else {
      // Extreme angles
      return clockAngle < 180 ? 90.0 : -90.0;
    }
  }

  return 0.0; // Default for front/undefined
}

/// Calculates signed deviation from a target clock angle.
/// Positive = clockwise from target, Negative = counter-clockwise.
/// Handles 360°/0° wraparound correctly.
/// For plank: positive = sag direction, negative = pike direction.
/// (verify with debug data and swap if needed)
double clockAngleDeviation(double clockAngle, double target) {
  double diff = clockAngle - target;
  // Normalize to -180..+180
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;
  return diff;
}
