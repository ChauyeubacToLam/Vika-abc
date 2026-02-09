// ignore_for_file: constant_identifier_names

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vinafit_mobile/utils/debouncer.dart';
import '../utils/pose_smoother.dart';
import '../utils/pose_math_helpers.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */

const double NODDING_ANGLE_FOR_START = 0.185; // 18.5% of the back length
const double FRONT_FACING_SHOULDER_THRESHOLD = 0.57; // > 0.57 is Front
const double SIDE_FACING_SHOULDER_THRESHOLD = 0.35; // < 0.35 is Side

enum ExerciseState {
  notActivated,
  activated,
  completed,
}

enum CameraFacing {
  front,
  left,
  right,
  angled,
  undefined,
}

/* A base class that handles the core pipeline for all fitness exercises.
   Manages Smoothing, Orientation, Safety, and State.
*/
abstract class ExerciseBase {
  late PoseSmoother poseSmoother;
  int repCount = 0;
  Map<String, String> feedbackMessage = {};
  List<Map<bool, Map<String, Map<String, String>>>> setFeedback = [];

  ExerciseState exerciseState = ExerciseState.notActivated;
  CameraFacing cameraFacing = CameraFacing.front;
  bool correctForm = true;
  double? distanceScaleFactor; // Back length (Shoulder to Hip)

  double frontFacingRatio =
      1.0; // Shoulder width / Torso height ratio for front view

  /// Debug data exposed for the UI debug overlay.
  /// Child classes populate this with exercise-specific metrics.
  Map<String, dynamic> debugData = {};

  ExerciseBase() {
    poseSmoother = PoseSmoother(minCutoff: 0.5, beta: 0.005);
  }

  Debouncer nodDebouncer =
      Debouncer(requiredFrames: 10); // 10 frames ~0.33s at 30fps

  /* -----------------------------------------------------------------------
     MAIN PIPELINE
     ----------------------------------------------------------------------- */
  List<dynamic>? processPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    feedbackMessage = {};

    // 1. Smooth the landmarks
    Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks =
        poseSmoother.smoothing(landmarks);

    // 2. Auto-detect Left/Right/Front (MUST come before safety check!)
    //    This updates frontFacingRatio and debugData
    cameraFacing = detectCameraFacing(smoothedLandmarks);

    // 3. Check for safety errors (Child class logic)
    //    Now has correct cameraFacing and frontFacingRatio values
    String? safetyError =
        checkSafety(smoothedLandmarks, cameraFacing, frontFacingRatio);
    if (safetyError != null) {
      feedbackMessage = {"System": safetyError};
      // Still populate debug data even on safety error
      debugData['exerciseState'] = exerciseState.toString().split('.').last;
      debugData['cameraFacing'] = cameraFacing.toString().split('.').last;
      return [repCount, feedbackMessage];
    }

    Pose pose = Pose(landmarks: smoothedLandmarks);

    // 4. Calculate Distance Scale Factor (Back Length)
    // We use getSideLandmark to get the dominant side's back length.
    // If Front view, it defaults to Left, which is acceptable for scaling.
    PoseLandmark? shoulder = getSideLandmark(
      pose: pose,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    PoseLandmark? hip = getSideLandmark(
      pose: pose,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );

    if (shoulder != null && hip != null) {
      distanceScaleFactor = calculateDistance(shoulder, hip);
    }

    // 5. Run State Machine (Start -> Active -> Done)
    exerciseState = checkExerciseState(pose, exerciseState,
        scaleFactor: distanceScaleFactor);

    // Populate base-level debug data
    debugData['exerciseState'] = exerciseState.toString().split('.').last;
    debugData['cameraFacing'] = cameraFacing.toString().split('.').last;
    debugData['scaleFactor'] = distanceScaleFactor?.toStringAsFixed(1) ?? 'N/A';

    if (exerciseState == ExerciseState.activated) {
      // Pass 'cameraFacing' so child class knows which side to check
      checkingPose(pose, cameraFacing, distanceScaleFactor);
      return getRepCountAndFeedback();
    } else if (exerciseState == ExerciseState.completed) {
      return getSetFeedback();
    }

    return null; // Idle
  }

  /* -----------------------------------------------------------------------
     ORIENTATION LOGIC
     ----------------------------------------------------------------------- */

  CameraFacing detectCameraFacing(
      Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    PoseLandmark? leftS = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    PoseLandmark? rightS = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    PoseLandmark? leftH = smoothedLandmarks[PoseLandmarkType.leftHip];

    if (leftS == null || rightS == null || leftH == null) {
      return CameraFacing.undefined;
    }

    double shoulderWidth = (leftS.x - rightS.x).abs(); // Use absolute value!
    double torsoHeight = calculateDistance(leftS, leftH);

    if (torsoHeight < 10) return CameraFacing.undefined;

    double ratio = shoulderWidth / torsoHeight;

    frontFacingRatio = ratio; // Store for debug/UI purposes

    // Add all values to debugData for in-app display
    debugData['leftS_x'] = leftS.x.toStringAsFixed(0);
    debugData['rightS_x'] = rightS.x.toStringAsFixed(0);
    debugData['shoulderWidth'] = shoulderWidth.toStringAsFixed(1);
    debugData['torsoHeight'] = torsoHeight.toStringAsFixed(1);
    debugData['facingRatio'] = ratio.toStringAsFixed(3);
    debugData['frontThresh'] = FRONT_FACING_SHOULDER_THRESHOLD.toString();
    debugData['sideThresh'] = SIDE_FACING_SHOULDER_THRESHOLD.toString();

    if (ratio > FRONT_FACING_SHOULDER_THRESHOLD) {
      return CameraFacing.front;
    } else if (ratio < SIDE_FACING_SHOULDER_THRESHOLD) {
      // It is side view. Use X-position to find which side.
      return isLeft(smoothedLandmarks) ? CameraFacing.left : CameraFacing.right;
    } else {
      return CameraFacing.angled;
    }
  }

  bool isLeft(Map<PoseLandmarkType, PoseLandmark>? smoothedLandmarks) {
    if (smoothedLandmarks == null) return true;
    double leftSConfidence =
        smoothedLandmarks[PoseLandmarkType.leftShoulder]?.likelihood ?? 0.0;
    double leftHipConfidence =
        smoothedLandmarks[PoseLandmarkType.leftHip]?.likelihood ?? 0.0;
    double leftKneeConfidence =
        smoothedLandmarks[PoseLandmarkType.leftKnee]?.likelihood ?? 0.0;
    double leftAnkleConfidence =
        smoothedLandmarks[PoseLandmarkType.leftAnkle]?.likelihood ?? 0.0;

    double rightSConfidence =
        smoothedLandmarks[PoseLandmarkType.rightShoulder]?.likelihood ?? 0.0;
    double rightHipConfidence =
        smoothedLandmarks[PoseLandmarkType.rightHip]?.likelihood ?? 0.0;
    double rightKneeConfidence =
        smoothedLandmarks[PoseLandmarkType.rightKnee]?.likelihood ?? 0.0;
    double rightAnkleConfidence =
        smoothedLandmarks[PoseLandmarkType.rightAnkle]?.likelihood ?? 0.0;

    double leftAvg = (leftSConfidence +
            leftHipConfidence +
            leftKneeConfidence +
            leftAnkleConfidence) /
        4.0;
    double rightAvg = (rightSConfidence +
            rightHipConfidence +
            rightKneeConfidence +
            rightAnkleConfidence) /
        4.0;

    return leftAvg <= rightAvg; // Camera is flipped so this is a reversed logic
  }

  /* -----------------------------------------------------------------------
     HELPERS
     ----------------------------------------------------------------------- */

  /* HELPER: Smart Selector
     - If Facing LEFT -> Returns Left Landmark
     - If Facing RIGHT -> Returns Right Landmark
     - If Facing FRONT/ANGLED -> Defaults to Left Landmark
     
     Use this for Side-View mechanics. For Front-View symmetry checks, 
     access pose.landmarks directly in the child class.
  */
  PoseLandmark? getSideLandmark({
    required Pose pose,
    required PoseLandmarkType rightType,
    required PoseLandmarkType leftType,
  }) {
    if (cameraFacing == CameraFacing.left) {
      return pose.landmarks[leftType];
    } else if (cameraFacing == CameraFacing.right) {
      return pose.landmarks[rightType];
    }
    // Default to left for front/angled views logic
    return pose.landmarks[leftType];
  }

  List getRepCountAndFeedback() => [repCount, feedbackMessage];

  List getSetFeedback() => setFeedback;

  /* -----------------------------------------------------------------------
     STATE MACHINE
     ----------------------------------------------------------------------- */

  ExerciseState checkExerciseState(Pose pose, ExerciseState currentState,
      {double? scaleFactor}) {
    switch (currentState) {
      case ExerciseState.notActivated:
        // Use smart selector to get the visible shoulder
        PoseLandmark? shoulder = getSideLandmark(
          pose: pose,
          rightType: PoseLandmarkType.rightShoulder,
          leftType: PoseLandmarkType.leftShoulder,
        );
        PoseLandmark? nose = pose.landmarks[PoseLandmarkType.nose];

        if (shoulder == null || nose == null) {
          return ExerciseState.notActivated;
        }

        // Check "Nod" (Nose drops down to shoulder level)
        double dist = (nose.y - shoulder.y).abs() / (scaleFactor ?? 1.0);
        debugData['nodDist'] = dist.toStringAsFixed(3);
        if (nodDebouncer.update(dist < NODDING_ANGLE_FOR_START)) {
          return ExerciseState.activated;
        }
        break;

      case ExerciseState.activated:
        // TEMPORARY: Auto-complete for testing
        if (repCount >= 15) return ExerciseState.completed;
        break;

      case ExerciseState.completed:
        break;
    }
    return currentState;
  }

  // ---------------------------------------------------------
  // ABSTRACT METHODS
  // ---------------------------------------------------------

  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
      CameraFacing cameraFacing, double? front_facingRatio);

  void checkingPose(Pose pose, CameraFacing cameraFacing, double? scaleFactor);
}
