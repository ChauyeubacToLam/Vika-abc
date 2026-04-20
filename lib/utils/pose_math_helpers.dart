import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../exercise/exercise_base.dart';

class _DepthSidePairSpec {
  const _DepthSidePairSpec(
    this.leftType,
    this.rightType, {
    required this.weight,
  });

  final PoseLandmarkType leftType;
  final PoseLandmarkType rightType;
  final double weight;
}

class _ObservedDepthSidePair {
  const _ObservedDepthSidePair({
    required this.left,
    required this.right,
    required this.weight,
  });

  final PoseLandmark left;
  final PoseLandmark right;
  final double weight;

  double get reliability =>
      ((left.likelihood + right.likelihood) / 2).clamp(0.25, 1.0).toDouble();
}

const List<_DepthSidePairSpec> _depthSidePairSpecs = [
  _DepthSidePairSpec(
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    weight: 1.4,
  ),
  _DepthSidePairSpec(
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    weight: 1.35,
  ),
  _DepthSidePairSpec(
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    weight: 1.15,
  ),
  _DepthSidePairSpec(
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
    weight: 1.0,
  ),
  _DepthSidePairSpec(
    PoseLandmarkType.leftElbow,
    PoseLandmarkType.rightElbow,
    weight: 0.8,
  ),
  _DepthSidePairSpec(
    PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist,
    weight: 0.6,
  ),
];

const double _depthPairZScoreGapThreshold = 0.35;
const double _depthDecisionMarginThreshold = 0.25;
const double _rawDepthGapThreshold = 0.01;

/// Returns:
/// - `true` when the user's left side is closer to camera
/// - `false` when the user's right side is closer to camera
/// - `null` when the depth signal is too weak to trust
///
/// Landmark Z values can vary in scale across frames and devices, so this
/// normalizes the observed depth spread before comparing paired left/right
/// joints. That makes left/right classification much more stable than using
/// a fixed raw-Z threshold alone.
bool? estimateIsLeftSideFromZScores(
  Map<PoseLandmarkType, PoseLandmark> landmarks,
) {
  final observedPairs = <_ObservedDepthSidePair>[];
  final allDepths = <double>[];

  for (final spec in _depthSidePairSpecs) {
    final left = landmarks[spec.leftType];
    final right = landmarks[spec.rightType];
    if (left == null || right == null) {
      continue;
    }

    observedPairs.add(
      _ObservedDepthSidePair(left: left, right: right, weight: spec.weight),
    );
    allDepths
      ..add(left.z)
      ..add(right.z);
  }

  if (observedPairs.length < 2) {
    return _estimateIsLeftSideFromRawDepth(observedPairs);
  }

  final meanDepth =
      allDepths.reduce((sum, value) => sum + value) / allDepths.length;
  final variance = allDepths.fold<double>(0, (sum, value) {
        final delta = value - meanDepth;
        return sum + delta * delta;
      }) /
      allDepths.length;
  final stdDev = math.sqrt(variance);

  if (stdDev <= 1e-6) {
    return _estimateIsLeftSideFromRawDepth(observedPairs);
  }

  var leftEvidence = 0.0;
  var rightEvidence = 0.0;
  var totalWeight = 0.0;

  for (final pair in observedPairs) {
    final leftZScore = (pair.left.z - meanDepth) / stdDev;
    final rightZScore = (pair.right.z - meanDepth) / stdDev;
    final zScoreGap = leftZScore - rightZScore;
    final pairWeight = pair.weight * pair.reliability;

    if (zScoreGap <= -_depthPairZScoreGapThreshold) {
      leftEvidence += (-zScoreGap) * pairWeight;
      totalWeight += pairWeight;
    } else if (zScoreGap >= _depthPairZScoreGapThreshold) {
      rightEvidence += zScoreGap * pairWeight;
      totalWeight += pairWeight;
    }
  }

  final normalizedMargin = totalWeight == 0
      ? 0.0
      : (leftEvidence - rightEvidence).abs() / totalWeight;

  if (normalizedMargin >= _depthDecisionMarginThreshold &&
      leftEvidence != rightEvidence) {
    return leftEvidence > rightEvidence;
  }

  return _estimateIsLeftSideFromRawDepth(observedPairs);
}

bool? _estimateIsLeftSideFromRawDepth(List<_ObservedDepthSidePair> pairs) {
  if (pairs.isEmpty) {
    return null;
  }

  var leftEvidence = 0.0;
  var rightEvidence = 0.0;
  var totalWeight = 0.0;

  for (final pair in pairs) {
    final depthGap = pair.left.z - pair.right.z;
    final pairWeight = pair.weight * pair.reliability;

    if (depthGap <= -_rawDepthGapThreshold) {
      leftEvidence += (-depthGap) * pairWeight;
      totalWeight += pairWeight;
    } else if (depthGap >= _rawDepthGapThreshold) {
      rightEvidence += depthGap * pairWeight;
      totalWeight += pairWeight;
    }
  }

  final normalizedMargin = totalWeight == 0
      ? 0.0
      : (leftEvidence - rightEvidence).abs() / totalWeight;

  if (normalizedMargin < _rawDepthGapThreshold ||
      leftEvidence == rightEvidence) {
    return null;
  }

  return leftEvidence > rightEvidence;
}

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
/* Not normalized version (0-360) for debugging and advanced use cases */

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

/* =========================================================================
   Calculate angle compare with the x coordinate (horizontal) 
   ========================================================================= */

/// For example, arm-x angle;
/// Returns 0° for arms horizontal, 90° for arms straight up.
/// Works for both left and right arms.
double calculateHorizontalAngle(
    {required PoseLandmark point1, required PoseLandmark point2}) {
  // Note: Y increases downward in screen coordinates.
  double dy = point1.y - point2.y;
  double dx = (point2.x - point1.x).abs();

  // atan2(dy, dx) gives angle from horizontal
  // When dy > 0 and dx small → near 90° (arm pointing up)
  // When dy ≈ 0 → near 0° (arm horizontal)
  // When dy < 0 → negative (arm pointing down)
  double radians = math.atan2(dy, dx);
  double degrees = radians * (180.0 / math.pi);

  // Clamp: below horizontal = 0, straight up = 90
  return degrees.clamp(0.0, 90.0);
}

/* =========================================================================
   Calculate distance between two points
   ========================================================================= */
double calculateDistance(dynamic point1, dynamic point2) {
  double dx = point2.x - point1.x;
  double dy = point2.y - point1.y;
  return math.sqrt(dx * dx + dy * dy);
}

/* =========================================================================
  Clock Angle to Trunk Lean Conversion
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
