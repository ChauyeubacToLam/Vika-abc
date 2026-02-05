// ignore_for_file: constant_identifier_names

import 'package:flutter/rendering.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../utils/pose_smoother.dart';

/* Represents the current lifecycle state of any exercise session.
  - notActivated: User is in frame but hasn't met start criteria.
  - activated: User is performing the exercise.
  - completed: Session finished (e.g., reached target reps).
*/

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */

const double NODDING_ANGLE_FOR_START = 0.185; // 18.5% of the back length

enum ExerciseState {
  notActivated,
  activated,
  completed,
}

/* A base class that handles the core pipeline for all fitness exercises.

  This class manages:
  1. Signal Smoothing: Applies the 1€ Filter to remove jitter.
  2. Safety Checks: Ensures user is visible.
  3. Orientation: Auto-detects Left vs Right side.
  4. State Machine: Transitions between states.

  How to use:
  Extend this class (e.g., class Squat extends ExerciseBase) and implement
  the abstract methods [checkSafety], [checkStartState], and [checkingPose].
*/
abstract class ExerciseBase {
  /* Handles temporal smoothing to reduce jitter/noise. */
  late PoseSmoother poseSmoother;

  /* Current number of valid repetitions. */
  int repCount = 0;

  /* Real-time feedback for the current frame (e.g., "Go Lower"). */
  Map<String, String> feedbackMessage = {};

  /* A history log of every repetition. */
  List<Map<bool, Map<String, Map<String, String>>>> setFeedback = [];

  /* The current stage of the exercise logic. */
  ExerciseState exerciseState = ExerciseState.notActivated;

  /* Detected orientation. 
    true = Left side visible. 
    false = Right side visible. 
  */
  bool? isLeft;

  /* Flag for current rep form. 
    Set to false if a fault is detected during the rep. 
  */
  bool correctForm = true;

  double? distanceScaleFactor;

  ExerciseBase() {
    /* Initialize the One Euro Filter.
      - minCutoff: 0.5 (Higher = less lag, more jitter).
      - beta: 0.005 (Sensitivity to speed).
    */
    poseSmoother = PoseSmoother(minCutoff: 0.5, beta: 0.005);
  }

  /* The main entry point for processing a camera frame.
    
    Returns:
    - [int repCount, Map feedback] if active.
    - List<Map> setFeedback if completed.
    - null if processing failed or idle.
  */
  List<dynamic>? processPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    feedbackMessage = {};

    // 1. Smooth the landmarks
    Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks =
        poseSmoother.smoothing(landmarks);

    // 2. Check for safety errors
    String? safetyError = checkSafety(smoothedLandmarks);
    if (safetyError != null) {
      feedbackMessage = {"System": safetyError};
      return [repCount, feedbackMessage];
    }

    Pose pose = Pose(landmarks: smoothedLandmarks);

    // 3. Determine left or right
    isLeft = leftOrRight(smoothedLandmarks);

    //4. Set  distance scale factor == back length
    PoseLandmark? shoulder = getLandmark(
      pose: pose,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    PoseLandmark? hip = getLandmark(
      pose: pose,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );

    if (shoulder != null && hip != null) {
      distanceScaleFactor =
          (shoulder.y - hip.y).abs(); // Vertical distance as scale factor
    }

    // 4. Start exercise logic
    exerciseState = checkExerciseState(pose, exerciseState,
        scaleFactor: distanceScaleFactor);

    if (exerciseState == ExerciseState.activated) {
      checkingPose(pose, isLeft!, distanceScaleFactor);
      return getRepCountAndFeedback();
    }
    // if done ()
    else if (exerciseState == ExerciseState.completed) {
      return getSetFeedback();
    }

    return null;
  }

  /* Auto-detects which side is facing the camera.
    Returns true if Left Shoulder is more confident than Right. 
  */
  bool leftOrRight(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    bool isLeft =
        (smoothedLandmarks[PoseLandmarkType.leftShoulder]?.likelihood ?? 0) >
            (smoothedLandmarks[PoseLandmarkType.rightShoulder]?.likelihood ??
                0);

    return isLeft;
  }

  /* Returns [count, feedback] for the UI. */
  List getRepCountAndFeedback() {
    return [repCount, feedbackMessage];
  }

  /* Returns complete history for summary screens. */
  List getSetFeedback() {
    return setFeedback;
  }

  /* Helper to get the correct landmark based on orientation.
    Example: If isLeft is true, it returns the Left version of the requested part.
  */
  PoseLandmark? getLandmark({
    required Pose pose,
    required PoseLandmarkType rightType,
    required PoseLandmarkType leftType,
  }) {
    return isLeft! ? pose.landmarks[leftType] : pose.landmarks[rightType];
  }

  /* Checks criteria to transition states (e.g., Start -> Active). 
  */
  ExerciseState checkExerciseState(Pose pose, ExerciseState currentState,
      {double? scaleFactor}) {
    switch (currentState) {
      case ExerciseState.notActivated:
        PoseLandmark? shoulder = getLandmark(
          pose: pose,
          rightType: PoseLandmarkType.rightShoulder,
          leftType: PoseLandmarkType.leftShoulder,
        );
        PoseLandmark? nose = pose.landmarks[PoseLandmarkType.nose];
        if (shoulder == null || nose == null) {
          return ExerciseState.notActivated;
        }
        double noseAndShoulderDistance =
            (nose.y - shoulder.y).abs() / (scaleFactor ?? 1.0);
        if (noseAndShoulderDistance < NODDING_ANGLE_FOR_START) {
          return ExerciseState.activated;
        }
        break;
      case ExerciseState.activated:
        // **** TEMPORARY: Auto-complete after 15 reps for testing ****
        if (repCount >= 15) {
          return ExerciseState.completed;
        }
        break;
      case ExerciseState.completed:
        break;
    }
    return currentState;
  }

  // ---------------------------------------------------------
  // ABSTRACT METHODS (Must be implemented by child classes)
  // ---------------------------------------------------------

  /* Validates if necessary body parts are visible.
    Return an error string if unsafe, or null if safe.
  */
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks);

  /* The core exercise logic loop.
    Calculates angles, counts reps, and checks form.
  */
  void checkingPose(Pose pose, bool isLeft, double? scaleFactor);
}
