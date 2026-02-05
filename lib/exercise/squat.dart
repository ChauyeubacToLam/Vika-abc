// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import '../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../utils/debouncer.dart';

import 'exercise_base.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */

const double MIN_CONFIDENCE = 0.98; // 98% confidence required
const int MARGIN_ANGLE_ERROR = 5;
const double MARGIN_POSITION_ERROR = 0.005;

/* KNEE ANGLES (0-180 Joint Logic)
 180 = Straight leg.
 < 150: Start of squat (Descending).
 > 115: Deep squat (Bottom/Ascending). 
 */
const SQUAT_STAND_ANGLE_THRESHOLD = 165 + MARGIN_ANGLE_ERROR;
const int SQUAT_DESCEND_ANGLE_THRESHOLD = 150 - MARGIN_ANGLE_ERROR;
const int SQUAT_ASCEND_ANGLE_THRESHOLD = 100 - MARGIN_ANGLE_ERROR;

// HIP ANGLES (40 deg is parallel/deep)
const int SQUAT_HIP_ANGLE_THRESHOLD = 40 + MARGIN_ANGLE_ERROR;

/* BACK POSTURE (0 is Vertical Up)
Facing Left: Forward < 300. Backward > 10.
*/
const int SQUAT_BACK_ANGLE_FORWARD_LIMIT = 332;
const int SQUAT_BACK_ANGLE_BACKWARD_LIMIT = 2;

/* Heel lift threshold (in normalized units)
HEEL CHECK (Relative to Shin Length)
0.08 means: "If heel is lifted more than 8% of the back length"
This makes it work even if the user is far away from the camera.
*/
const double SQUAT_HEEL_LIFT_THRESHOLD = 0.15; // 15%

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

  // debouncer for jitter prevention
  Debouncer backDebouncer =
      Debouncer(requiredFrames: 10); // 10 frames ~0.50s at 30fps
  Debouncer heelDebouncer =
      Debouncer(requiredFrames: 10); // 10 frames ~0.50s at 30fps
  Debouncer kneeDebouncer =
      Debouncer(requiredFrames: 10); // 10 frames ~0.33s at 30fps
  Debouncer hipDebouncer =
      Debouncer(requiredFrames: 10); // 10 frames ~0.33s at 30fps

  /* Error Accumulator
  Structure: { "PHASE": { "FaultType": "Message" } }
  Example: { "DESCENDING": { "Back": "Too Forward" } }
  */
  final Map<String, Map<String, String>> _currentRepFaults = {};

  /* Log a fault for the current rep.
    Parameters:
    - phase: The current phase of the squat (e.g., "DESCENDING").
    - type: The type/category of the fault (e.g., "Back").
    - message: A descriptive message for the fault.
    Logic:
    - If the fault type for the phase is not already logged, add it.
  */
  void _logFault(String phase, String type, String message) {
    if (!_currentRepFaults.containsKey(phase)) {
      _currentRepFaults[phase] = {};
    }
    // Only log the first error of this type per phase to keep logs clean
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
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final criticalTypes = [
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder
    ];

    for (var type in criticalTypes) {
      final landmark = landmarks[type];
      if (landmark == null) return "⚠️ Body not fully visible.";
      if (landmark.likelihood < MIN_CONFIDENCE)
        return "⚠️ Adjust lighting/position.";
    }
    return null;
  }

  /* -----------------------------------------------------------------------
     MAIN PHYSICS LOOP
     Called every frame when ExerciseState is 'activated'.
  ----------------------------------------------------------------------- */
  @override
  /* Main pose checking logic for Squat exercise.
    Parameters:
    - pose: The smoothed Pose object.
    - isLeft: Boolean indicating if left side is visible.
    - scaleFactor: Optional scaling factor for normalizing distances.

    Logic:
    1. Extract relevant landmarks for left or right side based on visibility.
    2. Calculate key angles and distances.
    3. Update state machine based on knee angle.
    4. Provide live feedback and log faults as needed.
  */

  void checkingPose(Pose pose, bool isLeft, double? scaleFactor) {
    // ----------1. Get Landmarks------------//

    PoseLandmark? knee = getLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? hip = getLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    PoseLandmark? ankle = getLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    PoseLandmark? shoulder = getLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);

    PoseLandmark? foot = getLandmark(
        pose: pose,
        rightType: PoseLandmarkType.rightFootIndex,
        leftType: PoseLandmarkType.leftFootIndex);

    PoseLandmark? heel = getLandmark(
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
    double hipAngle =
        calculateAngle(firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    double heelDistanceToFloor =
        foot.y - heel.y; // y coordinate increases upwards from the bottom

    // ----------3. Logic: Rep Completion (Standing Up) -----------//

    if (kneeAngle > SQUAT_STAND_ANGLE_THRESHOLD) {
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
      backDebouncer.reset();
      heelDebouncer.reset();
      kneeDebouncer.reset();
      return;
    }

    // ----------4. Update State Machine -----------//

    detectSquatState(kneeAngle);

    String currentPhase = squatState.toString().split('.').last.toUpperCase();

    // ----------5. Live Feedback & Fault Logging -----------//

    if (squatState != SquatState.standing) {
      checkBack(backAngle, isLeft, currentPhase);
      checkHeels(heelDistanceToFloor, scaleFactor: scaleFactor);

      if (squatState == SquatState.descending) {
        checkDepthAndHip(knee.y, hip.y, kneeAngle, hipAngle, currentPhase);
        feedbackMessage["Status"] = "Going Down...";
      } else if (squatState == SquatState.bottom) {
        checkDepthAndHip(knee.y, hip.y, kneeAngle, hipAngle, currentPhase);
        feedbackMessage["Status"] = "Hold Bottom";
      } else if (squatState == SquatState.ascending) {
        feedbackMessage["Status"] = "Push Up!";
      }
    }
  }

  /* -----------------------------------------------------------------------
                                METRICS CHECKS
                  Apply 1 euro filtering and debouncing here
  ----------------------------------------------------------------------- */

  /* Check Depth and Hip Positioning 
    Parameters:
    - kneeY: Y position of the knee landmark.
    - hipY: Y position of the hip landmark.
    - kneeAngle: Current angle at the knee joint.
    - hipAngle: Current angle at the hip joint.
    - phase: Current phase of the squat (for logging).

    Logic:
    - Hip Check: At bottom, hips must be open (hipAngle >= threshold).
    - Depth Check: During descent, kneeY must be lower than hipY for good depth
    - Hip Check is only strict at the bottom position to avoid sensor noise.
  */
  void checkDepthAndHip(double kneeY, double hipY, double kneeAngle,
      double hipAngle, String phase) {
    // Hip Check (Only strict at bottom to avoid sensor noise)
    if (squatState == SquatState.bottom) {
      if (hipDebouncer.update(hipAngle < SQUAT_HIP_ANGLE_THRESHOLD)) {
        feedbackMessage["Hip"] = "Open Hips";
        _logFault(phase, "Hip", "Hips too tight/tucked");
      }
    }

    // Depth Check
    // bigger y value means lower position
    if (squatState == SquatState.descending &&
        kneeAngle > SQUAT_DESCEND_ANGLE_THRESHOLD &&
        kneeY <= hipY) {
      feedbackMessage["Depth"] = "Go Lower";
    } else if (squatState == SquatState.bottom) {
      feedbackMessage["Depth"] = "Good Depth";
    }
  }

  /* Check Back Posture 
    Parameters:
    - angle: Current back angle relative to vertical.
    - isLeft: Boolean indicating if left side is visible.
    - phase: Current phase of the squat (for logging).

    Logic:
    - Leaning Forward: If back angle exceeds forward limit.
    - Leaning Backward: If back angle exceeds backward limit.
  */
  void checkBack(double angle, bool isLeft, String phase) {
    bool leanForward = false;
    bool leanBackward = false;

    // Determine facing direction logic
    if (isLeft) {
      if (angle <= SQUAT_BACK_ANGLE_FORWARD_LIMIT && angle > 150)
        leanForward = true;
      if (angle >= SQUAT_BACK_ANGLE_BACKWARD_LIMIT && angle < 100)
        leanBackward = true;
    } else {
      // Mirror logic for right side
      if (angle >= (360 - SQUAT_BACK_ANGLE_FORWARD_LIMIT)) leanForward = true;
      if (angle <= (360 - SQUAT_BACK_ANGLE_BACKWARD_LIMIT) && angle > 100)
        leanBackward = true;
    }

    if (backDebouncer.update(leanForward)) {
      feedbackMessage["Back"] = "Chest up!";
      _logFault(phase, "Back", "Leaned too forward");
    } else if (backDebouncer.update(leanBackward)) {
      feedbackMessage["Back"] = "Don't lean back!";
      _logFault(phase, "Back", "Leaned backward");
    } else {
      feedbackMessage["Back"] = "Good back";
    }
  }

  /* Check Heel Position 
    Parameters:
    - heelDistanceToFloor: Vertical distance from heel to floor.
    - scaleFactor: Optional scaling factor for normalization.

    Logic:
    - If heel is lifted beyond threshold, log fault and provide feedback.
  */
  void checkHeels(double heelDistanceToFloor, {double? scaleFactor}) {
    if (heelDebouncer.update(heelDistanceToFloor / (scaleFactor ?? 1.0) >=
        SQUAT_HEEL_LIFT_THRESHOLD)) {
      feedbackMessage["Feet"] = "Keep Heels Down";
      _logFault("GENERAL", "Feet", "Heels lifted off the ground");
      correctForm = false;
    } else {
      feedbackMessage["Feet"] = "Good Heels";
    }
  }

  /* ================================ 
    STATE MACHINE 
     ================================ */
  void detectSquatState(double kneeAngle) {
    // Transition: Standing -> Descending
    if (kneeAngle <= SQUAT_DESCEND_ANGLE_THRESHOLD &&
        squatState == SquatState.standing) {
      squatState = SquatState.descending;
      _currentRepFaults.clear(); // Safety clear
    }
    // Transition: Descending -> Bottom
    else if (kneeAngle <= SQUAT_ASCEND_ANGLE_THRESHOLD &&
        squatState == SquatState.descending) {
      squatState = SquatState.bottom;
    }
    // Transition: Bottom -> Ascending
    // Added +5 buffer to prevent flickering at the very bottom
    else if (kneeAngle > (SQUAT_ASCEND_ANGLE_THRESHOLD + 5) &&
        squatState == SquatState.bottom) {
      squatState = SquatState.ascending;
    }
  }
}
