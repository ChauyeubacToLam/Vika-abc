import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/* ---------------------------------------------------------------------------
  PART 1: JOINT FLEXION (0 - 180 degrees)
  ---------------------------------------------------------------------------
  Measures the angle between three landmarks (e.g., Hip -> Knee -> Ankle).
  Logic adapted directly from Google ML Kit documentation.
*/
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

  // 4. Normalize to acute representation (always <= 180)
  if (degrees > 180.0) {
    degrees = 360.0 - degrees;
  }

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
