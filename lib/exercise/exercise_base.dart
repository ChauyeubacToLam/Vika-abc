// ignore_for_file: constant_identifier_names

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vinafit_mobile/utils/debouncer.dart';
import 'package:vinafit_mobile/utils/person_detector.dart';
import '../utils/pose_smoother.dart';
import '../utils/pose_math_helpers.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */

const double NODDING_ANGLE_FOR_START = 0.2; // 20% of the back length
const double FRONT_FACING_SHOULDER_THRESHOLD = 0.57; // > 0.57 is Front
const double SIDE_FACING_SHOULDER_THRESHOLD = 0.35; // < 0.35 is Side

/* =========================================================================
   ENUMS
   ========================================================================= */

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

class ResultIssues {
  Map<String, String> feedback = {};
  Map<String, Map<String, String>> instructions = {};

  void addInstruction(String phase, String type, String message) {
    instructions.putIfAbsent(phase, () => {});
    instructions[phase]![type] = message;
  }

  void clear() {
    feedback.clear();
    instructions.clear();
  }
}

/* =========================================================================
   ExerciseBase - abstract base class for all fitness exercises.
   ========================================================================= */

abstract class ExerciseBase {
  // -- Core State --
  late PoseSmoother poseSmoother;
  int repCount = 0;
  static const MIN_CONFIDENCE = 0.92;

  List<Map<bool, Map<String, Map<String, String>>>> setFeedback = [];
  ResultIssues resultIssues = ResultIssues();

  ExerciseState exerciseState = ExerciseState.notActivated;
  CameraFacing cameraFacing = CameraFacing.front;
  bool correctForm = true;
  double? distanceScaleFactor;
  double frontFacingRatio = 1.0;

  Map<String, dynamic> debugData = {};

  // -- Orientation --
  StickyDebouncer leftRightDebouncer = StickyDebouncer(requiredFrames: 5);

  // -- Person Detection (Selfie Segmentation) --
  // Replaces all heuristic object filters with one ML-based check.
  // Only runs before activation — once person confirmed + nod, stops.
  final PersonDetector _personDetector = PersonDetector();

  // StickyDebouncer: starts as "not detected" (false).
  // Requires N consecutive "person detected" frames to pass.
  // Requires N consecutive "no person" frames to block again.
  StickyDebouncer _personDetectedDebouncer =
      StickyDebouncer(requiredFrames: 15, currentState: false);

  // Track if person detection has ever passed (to avoid re-checking
  // after brief detection gaps during nod animation)
  bool _personConfirmed = false;

  // -- Periodic Segmentation (mid-set person check) --
  // Runs once every ~1.5s during active exercise to detect if user left.
  int _segCheckCounter = 0;
  int _segFailStreak = 0;
  bool _isPaused = false;

  static const int _SEG_CHECK_INTERVAL = 30; // frames (~1.5s at 30fps)
  static const int _SEG_FAIL_THRESHOLD = 1; // consecutive fails to pause

  /// Whether the exercise is currently paused (user left frame).
  bool get isPaused => _isPaused;

  // -- Constructor --
  ExerciseBase() {
    poseSmoother = PoseSmoother(minCutoff: 0.5, beta: 0.005);
  }

  /* -----------------------------------------------------------------------
     MAIN PIPELINE
     ----------------------------------------------------------------------- */

  /// Main entry point. Called every frame from the camera stream.
  /// [inputImage] is needed for person detection (segmentation).
  /// [landmarks] are the pose landmarks from ML Kit Pose Detection.
  List<dynamic>? processPose(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    InputImage? inputImage,
  }) {
    resultIssues.feedback.clear();

    // 1. Smooth
    final smoothedLandmarks = poseSmoother.smoothing(landmarks);

    // 2. Person Detection — only before activation
    if (exerciseState == ExerciseState.notActivated && !_personConfirmed) {
      // Check last known result from async person detector
      bool personOk =
          _personDetectedDebouncer.update(_personDetector.personDetected);

      debugData['personRatio'] =
          _personDetector.lastPersonRatio.toStringAsFixed(3);
      debugData['personOk'] = personOk;

      if (!personOk) {
        resultIssues.feedback["System"] =
            "Đang tìm người... Vui lòng đứng trong khung hình.";
        _populateBaseDebugData();
        return [repCount, resultIssues.feedback];
      }

      // Person confirmed — stop running segmentation
      _personConfirmed = true;
    }

    // 2b. Periodic segmentation during active exercise
    if (exerciseState == ExerciseState.activated) {
      _segCheckCounter++;

      // Read last async result
      if (_segCheckCounter >= _SEG_CHECK_INTERVAL) {
        _segCheckCounter = 0;

        if (!_personDetector.personDetected) {
          _segFailStreak++;
          debugData['segFailStreak'] = _segFailStreak;

          if (_segFailStreak >= _SEG_FAIL_THRESHOLD) {
            _isPaused = true;
          }
        } else {
          _segFailStreak = 0;
          _isPaused = false;
        }
      }

      debugData['isPaused'] = _isPaused;

      if (_isPaused) {
        resultIssues.feedback["System"] =
            "⏸ Tạm dừng — Quay lại khung hình để tiếp tục";
        _populateBaseDebugData();
        return [repCount, resultIssues.feedback];
      }
    }

    // 3. Auto-detect orientation
    cameraFacing = detectCameraFacing(smoothedLandmarks);

    // 4. Safety check (child class logic)
    final safetyError = checkSafety(smoothedLandmarks, cameraFacing);
    if (safetyError != null) {
      resultIssues.feedback["System"] = safetyError;
      _populateBaseDebugData();
      return [repCount, resultIssues.feedback];
    }

    // 5. Calculate Distance Scale Factor (Back Length)
    final shoulder = getSideLandmark(
      landmarks: smoothedLandmarks,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    final hip = getSideLandmark(
      landmarks: smoothedLandmarks,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );
    if (shoulder != null && hip != null) {
      distanceScaleFactor = calculateDistance(shoulder, hip);
    }

    // 6. State Machine
    checkExerciseState(smoothedLandmarks, exerciseState,
        scaleFactor: distanceScaleFactor);

    _populateBaseDebugData();
    debugData['scaleFactor'] = distanceScaleFactor?.toStringAsFixed(1) ?? 'N/A';

    if (exerciseState == ExerciseState.activated) {
      checkingPose(smoothedLandmarks, cameraFacing, distanceScaleFactor);
      return getRepCountAndFeedback();
    } else if (exerciseState == ExerciseState.completed) {
      return getSetFeedback();
    }

    return null;
  }

  /// Async person detection — call from camera stream handler.
  /// Fire-and-forget: results are read synchronously in processPose().
  /// Runs during notActivated (gate) AND activated (periodic mid-set check).
  Future<void> runPersonDetection(InputImage inputImage) async {
    if (exerciseState == ExerciseState.completed) return;

    // Before activation: run every frame until confirmed
    if (exerciseState == ExerciseState.notActivated && _personConfirmed) return;

    // During activation: only run on check intervals
    if (exerciseState == ExerciseState.activated &&
        _segCheckCounter != _SEG_CHECK_INTERVAL - 1 &&
        !_isPaused) {
      return; // Not time to check yet
    }

    // If paused, run every frame to detect return quickly
    await _personDetector.detect(inputImage);
  }

  /// Call when exercise screen is disposed to free native resources.
  Future<void> disposeDetectors() async {
    await _personDetector.close();
  }

  void _populateBaseDebugData() {
    debugData['exerciseState'] = exerciseState.toString().split('.').last;
    debugData['cameraFacing'] = cameraFacing.toString().split('.').last;
  }

  /* -----------------------------------------------------------------------
     ORIENTATION LOGIC
     ----------------------------------------------------------------------- */

  CameraFacing detectCameraFacing(
      Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final leftS = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rightS = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final leftH = smoothedLandmarks[PoseLandmarkType.leftHip];

    if (leftS == null || rightS == null || leftH == null) {
      return CameraFacing.undefined;
    }

    final shoulderWidth = (leftS.x - rightS.x);
    final torsoHeight = calculateDistance(leftS, leftH);

    if (torsoHeight < 10) return CameraFacing.undefined;

    final ratio = shoulderWidth.abs() / torsoHeight;
    frontFacingRatio = ratio;

    if (ratio > FRONT_FACING_SHOULDER_THRESHOLD) {
      return CameraFacing.front;
    } else if (ratio < SIDE_FACING_SHOULDER_THRESHOLD) {
      return _isLeftSide(smoothedLandmarks)
          ? CameraFacing.left
          : CameraFacing.right;
    } else {
      return CameraFacing.angled;
    }
  }

  bool _isLeftSide(Map<PoseLandmarkType, PoseLandmark>? smoothedLandmarks) {
    if (smoothedLandmarks == null) return false;

    const pairs = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle],
    ];

    int leftVotes = 0;
    int rightVotes = 0;
    for (final pair in pairs) {
      final leftLM = smoothedLandmarks[pair[0]];
      final rightLM = smoothedLandmarks[pair[1]];
      if (leftLM == null || rightLM == null) continue;

      final zDiff = leftLM.z - rightLM.z;
      double threshold = 0.01;
      if (zDiff.abs() > threshold) {
        if (zDiff < 0) {
          leftVotes++;
        } else {
          rightVotes++;
        }
      }
    }
    return leftRightDebouncer.update(leftVotes >= rightVotes);
  }

  /* -----------------------------------------------------------------------
     HELPERS
     ----------------------------------------------------------------------- */

  PoseLandmark? getSideLandmark({
    required Map<PoseLandmarkType, PoseLandmark> landmarks,
    required PoseLandmarkType rightType,
    required PoseLandmarkType leftType,
  }) {
    if (cameraFacing == CameraFacing.right) {
      return landmarks[rightType];
    }
    return landmarks[leftType];
  }

  List<dynamic> getRepCountAndFeedback() => [repCount, resultIssues.feedback];

  List<dynamic> getSetFeedback() => setFeedback;

  /* -----------------------------------------------------------------------
     STATE MACHINE
     ----------------------------------------------------------------------- */

  void checkExerciseState(
    Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
    ExerciseState currentState, {
    double? scaleFactor,
  }) {
    switch (currentState) {
      case ExerciseState.notActivated:
        final shoulder = getSideLandmark(
          landmarks: smoothedLandmarks,
          rightType: PoseLandmarkType.rightShoulder,
          leftType: PoseLandmarkType.leftShoulder,
        );
        final nose = smoothedLandmarks[PoseLandmarkType.nose];

        if (shoulder == null || nose == null) {
          exerciseState = ExerciseState.notActivated;
          return;
        }

        final dist = (nose.y - shoulder.y).abs() / (scaleFactor ?? 1.0);
        debugData['nodDist'] = dist.toStringAsFixed(3);

        if (dist < NODDING_ANGLE_FOR_START) {
          exerciseState = ExerciseState.activated;
        }
        break;

      case ExerciseState.activated:
        if (requestStop()) exerciseState = ExerciseState.completed;
        break;

      case ExerciseState.completed:
        break;
    }
  }

  /* -----------------------------------------------------------------------
     ABSTRACT METHODS
     ----------------------------------------------------------------------- */
  bool requestStop();

  String? checkSafety(
    Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
    CameraFacing cameraFacing,
  );

  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
      CameraFacing cameraFacing, double? scaleFactor);

  /* -----------------------------------------------------------------------
     UI BRIDGE
     ----------------------------------------------------------------------- */
  String get exerciseName;
  String get currentPhaseKey;
  String get currentPhaseLabel;
}
