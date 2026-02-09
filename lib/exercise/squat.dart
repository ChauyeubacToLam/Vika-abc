// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import '../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../utils/debouncer.dart';

import 'exercise_base.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */
class SquatConfig {
  static const double MIN_CONFIDENCE = 0.98; // 98% confidence required

  /* KNEE ANGLES (0-180 Joint Logic)
     180 = Straight leg.
     <= 130: Start of squat (Descending).
     80-115: Deep squat (Bottom/Ascending).
  */
  static const int SQUAT_STAND_ANGLE_THRESHOLD =
      160; // Must be above 160 to count rep (prevents half-squats)

  static const int SQUAT_DESCEND_ANGLE_THRESHOLD =
      130; // Start tracking descent at 130 (spec page 4)

  static const List<int> SQUAT_BOTTOM_ANGLE_THRESHOLD = [
    80,
    115
  ]; // 80-115 is the typical range for the bottom/ascending phase

  /* TRUNK LEAN (Degrees from vertical, converted from clock angle)
     Good range: 15-40 degrees from vertical
     Wide range accounts for Vietnamese body types (short torso = more forward lean is OK)
  */
  static const List<int> SQUAT_GOOD_BACK_ANGLE = [15, 50];
  static const double SQUAT_BACK_ANGLE_BACKWARD_LIMIT = 0.02;

  /* HEEL LIFT (Normalized to back length)
     0.15 means: "If heel is lifted more than 15% of the back length"
     This makes it work even if the user is far away from the camera.
  */
  static const double SQUAT_HEEL_LIFT_THRESHOLD = 0.15; // 15%
}

enum SquatState {
  standing,
  descending,
  bottom,
  ascending,
}

/* =========================================================================
   SQUAT LOGIC
   ========================================================================= */

/* Handles the biomechanics logic for the Squat exercise.
   State Machine:
   Standing -> Descending -> Bottom -> Ascending -> Standing (Rep Counted)
*/

class Squat extends ExerciseBase {
  SquatState squatState = SquatState.standing;

  // Debouncers for jitter prevention
  // IMPORTANT: Use SEPARATE debouncers for forward/backward - they can't share!
  Debouncer backForwardDebouncer =
      Debouncer(requiredFrames: 5); // Forward lean detection
  Debouncer backBackwardDebouncer =
      Debouncer(requiredFrames: 5); // Backward lean detection
  Debouncer heelDebouncer =
      Debouncer(requiredFrames: 10); // 10 frames ~0.33s at 30fps

  /* Error Accumulator
     Structure: { "PHASE": { "FaultType": "Message" } }
     Example: { "DESCENDING": { "Back": "Too Forward" } }
  */
  final Map<String, Map<String, String>> _currentRepFaults = {};

  /* Log a fault for the current rep.
     Only logs the first error of this type per phase to keep logs clean.
  */
  void _logFault(String phase, String type, String message) {
    if (!_currentRepFaults.containsKey(phase)) {
      _currentRepFaults[phase] = {};
    }
    if (!_currentRepFaults[phase]!.containsKey(type)) {
      _currentRepFaults[phase]![type] = message;
      correctForm = false;
    }
  }

  /* -----------------------------------------------------------------------
     SAFETY CHECKS
     Ensures all critical landmarks are visible with high confidence.
  ----------------------------------------------------------------------- */
  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks,
      CameraFacing cameraFacing, double? frontFacingRatio) {
    final criticalTypes = [
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder
    ];

    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Please turn to the side for better tracking for Squat ";
    }

    for (var type in criticalTypes) {
      final landmark = landmarks[type];
      if (landmark == null) return "⚠️ Body not fully visible.";
      if (landmark.likelihood < SquatConfig.MIN_CONFIDENCE)
        return "⚠️ Adjust lighting/position.";
    }
    return null;
  }

  /* -----------------------------------------------------------------------
     MAIN PHYSICS LOOP
     Called every frame when ExerciseState is 'activated'.
  ----------------------------------------------------------------------- */
  @override
  void checkingPose(Pose pose, CameraFacing cameraFacing, double? scaleFactor) {
    // ----------1. Get Landmarks------------//

    PoseLandmark? knee = getSideLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? hip = getSideLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    PoseLandmark? ankle = getSideLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    PoseLandmark? shoulder = getSideLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? foot = getSideLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightFootIndex,
        leftType: PoseLandmarkType.leftFootIndex);
    PoseLandmark? heel = getSideLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightHeel,
        leftType: PoseLandmarkType.leftHeel);

    if (knee == null ||
        hip == null ||
        ankle == null ||
        shoulder == null ||
        foot == null ||
        heel == null) return;

    // ----------2. Calculate Geometry------------//

    double kneeAngle =
        calculateAngle(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    double backAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    double trunkLean = convertClockAngleToTrunkLean(backAngle, cameraFacing);
    double heelDistanceToFloor =
        foot.y - heel.y; // y coordinate increases upwards from the bottom
    double heelNormalized = heelDistanceToFloor / (scaleFactor ?? 1.0);

    // ---------- Populate Debug Data ----------//

    debugData['squatState'] = squatState.toString().split('.').last;
    debugData['kneeAngle'] = kneeAngle.toStringAsFixed(1);
    debugData['backClockAngle'] = backAngle.toStringAsFixed(1);
    debugData['trunkLean'] =
        '${trunkLean >= 0 ? "+" : ""}${trunkLean.toStringAsFixed(1)}°';
    debugData['trunkLeanDir'] = trunkLean >= 0 ? 'Forward' : 'Backward';
    debugData['heelDist'] = heelDistanceToFloor.toStringAsFixed(2);
    debugData['heelNorm'] = heelNormalized.toStringAsFixed(3);
    debugData['correctForm'] = correctForm.toString();

    // ----------3. Logic: Rep Completion (Standing Up) -----------//

    if (kneeAngle > SquatConfig.SQUAT_STAND_ANGLE_THRESHOLD) {
      // Only count if they were actually doing a squat
      if (squatState != SquatState.standing) {
        repCount += 1;

        // Validation: Did they go deep enough?
        if (squatState != SquatState.ascending) {
          // If they stand up from 'descending', they missed depth.
          _logFault("BOTTOM", "Depth", "Too Shallow (Missed Rep)");
        }

        // UI Feedback for the finished rep
        feedbackMessage["Result"] = correctForm ? "Good Rep!" : "Fix Form";

        /* SAVE HISTORY (Unified Logic)
           If correctForm is True -> Map is empty (Good).
           If correctForm is False -> Map has details (Bad).
        */
        setFeedback.add({correctForm: Map.from(_currentRepFaults)});
      }

      // Reset for next rep
      squatState = SquatState.standing;
      _currentRepFaults.clear();
      correctForm = true;
      backForwardDebouncer.reset();
      backBackwardDebouncer.reset();
      heelDebouncer.reset();
      return;
    }

    // ----------4. Update State Machine -----------//

    detectSquatState(kneeAngle);

    String currentPhase = squatState.toString().split('.').last.toUpperCase();

    // ----------5. Live Feedback & Fault Logging -----------//

    if (squatState != SquatState.standing) {
      checkBack(backAngle, cameraFacing, currentPhase);
      checkHeels(heelDistanceToFloor, currentPhase, scaleFactor: scaleFactor);

      if (squatState == SquatState.descending) {
        checkDepth(knee.y, hip.y, kneeAngle, currentPhase);
        feedbackMessage["Status"] = "Going Down...";
      } else if (squatState == SquatState.bottom) {
        checkDepth(knee.y, hip.y, kneeAngle, currentPhase);
        feedbackMessage["Status"] = "Hold Bottom";
      } else if (squatState == SquatState.ascending) {
        feedbackMessage["Status"] = "Push Up!";
      }
    }
  }

  /* -----------------------------------------------------------------------
                                METRICS CHECKS
  ----------------------------------------------------------------------- */

  /* Check Depth
     - Good: 80-110° (parallel or deeper)
     - Deep squat (<80°): Celebrated, not penalized
     - Warning: still above 110° during descent
  */
  void checkDepth(double kneeY, double hipY, double kneeAngle, String phase) {
    if (kneeAngle < SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[0]) {
      // Below 80° = deep squat - celebrate it!
      feedbackMessage["Depth"] = "Deep Squat!";
    } else if (kneeAngle >= SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[0] &&
        kneeAngle <= SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1]) {
      feedbackMessage["Depth"] = "Good Depth";
    } else if (squatState == SquatState.descending &&
        kneeAngle > SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1] &&
        kneeY >= hipY) {
      // Note: In our coordinates, Y increases upward, so kneeY >= hipY
      // means knee hasn't dropped below hip yet
      feedbackMessage["Depth"] = "Go Lower";
    } else {
      feedbackMessage["Depth"] = "Good Depth";
    }
  }

  /* Check Back Posture (Trunk Lean)
     - Converts clock angle to degrees-from-vertical
     - Good range: 15-50° (wide range for Vietnamese biomechanics)
     - Forward lean > 50°: "Chest up!"
     - Backward lean < 3°: "Don't lean back!"
  */
  void checkBack(double clockAngle, CameraFacing cameraFacing, String phase) {
    // Get signed trunk lean: positive = forward, negative = backward
    double trunkLean = convertClockAngleToTrunkLean(clockAngle, cameraFacing);

    bool leanForward =
        trunkLean > SquatConfig.SQUAT_GOOD_BACK_ANGLE[1]; // > 50°
    bool leanBackward =
        trunkLean < -SquatConfig.SQUAT_BACK_ANGLE_BACKWARD_LIMIT; // < -0.02°

    // Use SEPARATE debouncers - each tracks its own condition independently
    bool forwardConfirmed = backForwardDebouncer.update(leanForward);
    bool backwardConfirmed = backBackwardDebouncer.update(leanBackward);

    if (forwardConfirmed) {
      feedbackMessage["Back"] = "Chest up!";
      _logFault(phase, "Back", "Leaned too forward");
    } else if (backwardConfirmed) {
      feedbackMessage["Back"] = "Don't lean back!";
      _logFault(phase, "Back", "Leaned backward");
    } else {
      feedbackMessage["Back"] = "Good back";
    }
  }

  /* Check Heel Position
     - Informational only: does NOT mark correctForm = false
     - Heel rise is treated as a mobility observation, not an error
     - Suggests a practical fix (book/yoga block under heels)
  */
  void checkHeels(double heelDistanceToFloor, String phase,
      {double? scaleFactor}) {
    double normalized = heelDistanceToFloor / (scaleFactor ?? 1.0);

    if (heelDebouncer
        .update(normalized >= SquatConfig.SQUAT_HEEL_LIFT_THRESHOLD)) {
      feedbackMessage["Feet"] = "Heels lifting - try elevating heels";
      _logFault(phase, "Feet", "Heels lifting");
    } else {
      feedbackMessage["Feet"] = "Good Heels";
    }
  }

  /* ================================
     STATE MACHINE
     ================================ */
  void detectSquatState(double kneeAngle) {
    // Transition: Standing -> Descending
    if (kneeAngle <= SquatConfig.SQUAT_DESCEND_ANGLE_THRESHOLD &&
        squatState == SquatState.standing) {
      squatState = SquatState.descending;
      _currentRepFaults.clear(); // Safety clear
    }
    // Transition: Descending -> Bottom
    else if (kneeAngle <= SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1] &&
        kneeAngle >= SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[0] &&
        squatState == SquatState.descending) {
      squatState = SquatState.bottom;
    }
    // Transition: Bottom -> Ascending
    // Added +5 buffer to prevent flickering at the very bottom
    else if (kneeAngle > (SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1] + 5) &&
        squatState == SquatState.bottom) {
      squatState = SquatState.ascending;
    }
  }
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
