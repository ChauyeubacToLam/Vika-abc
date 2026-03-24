// ignore_for_file: constant_identifier_names

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vinafit_mobile/utils/debouncer.dart';
import 'package:vinafit_mobile/utils/person_detector.dart';
import '../utils/pose_smoother.dart';
import '../utils/pose_math_helpers.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */

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
   
   Activation: hold-still (universal).
   Each exercise overrides isInStartPosition() to define what
   "ready" looks like (standing for squat, horizontal for plank/push-up).
   User holds valid position for 3 seconds → exercise begins.
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

  // -- FPS Tracking --
  DateTime? _lastFrameTime;
  double _currentFps = 30.0;

  double get currentFps => _currentFps;
  double get fpsRatio => _currentFps / 30.0;

  // -- Person Detection (Selfie Segmentation) --
  final PersonDetector _personDetector = PersonDetector();
  bool _personConfirmed = false;
  DateTime? _personSeenSince;
  DateTime? _personLostSince;
  DateTime? _resumePresenceSince;

  bool _isPaused = false;

  static const Duration _PERSON_CONFIRM_DURATION = Duration(milliseconds: 650);
  static const Duration _PERSON_LOST_GRACE = Duration(milliseconds: 900);
  static const Duration _PERSON_RESUME_CONFIRM_DURATION =
      Duration(milliseconds: 320);

  /// Whether the exercise is currently paused (user left frame).
  bool get isPaused => _isPaused;

  double get personPresenceScore => _personDetector.presenceScore;

  // -- Hold-Still Activation --
  DateTime? _holdStillStartedAt;
  static const Duration HOLD_STILL_REQUIRED_DURATION = Duration(seconds: 3);

  /// Progress 0.0–1.0 for hold-still countdown UI. Null if not in countdown.
  double? get activationProgress {
    if (exerciseState != ExerciseState.notActivated) return null;
    if (!_personConfirmed) return null;
    if (_holdStillStartedAt == null) return null;
    final elapsed = DateTime.now().difference(_holdStillStartedAt!);
    return (elapsed.inMilliseconds /
            HOLD_STILL_REQUIRED_DURATION.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  // -- Constructor --
  ExerciseBase() {
    poseSmoother = PoseSmoother(minCutoff: 0.5, beta: 0.005);
  }

  /* -----------------------------------------------------------------------
     MAIN PIPELINE
     ----------------------------------------------------------------------- */

  List<dynamic>? processPose(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    InputImage? inputImage,
  }) {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final deltaMs = now.difference(_lastFrameTime!).inMilliseconds;
      if (deltaMs > 0) {
        final frameFps = 1000.0 / deltaMs;
        _currentFps = _currentFps * 0.9 + frameFps * 0.1;
      }
    }
    _lastFrameTime = now;

    resultIssues.feedback.clear();

    // 1. Smooth
    final smoothedLandmarks = poseSmoother.smoothing(landmarks);

    _syncPresenceState(hasPose: true);

    debugData['personRatio'] =
        _personDetector.lastPersonRatio.toStringAsFixed(3);
    debugData['personScore'] = _personDetector.presenceScore.toStringAsFixed(3);
    debugData['personDetected'] = _personDetector.personDetected;

    // 2. Person Detection — only before activation
    if (exerciseState == ExerciseState.notActivated && !_personConfirmed) {
      final stableFor = _personSeenSince == null
          ? 0
          : DateTime.now().difference(_personSeenSince!).inMilliseconds;
      debugData['personStableMs'] = stableFor;

      if (!_personConfirmed) {
        resultIssues.feedback["System"] =
            "Đang tìm người... Vui lòng đứng trong khung hình.";
        _populateBaseDebugData();
        return [repCount, resultIssues.feedback];
      }
    }

    // 2b. Presence re-check during active exercise
    if (exerciseState == ExerciseState.activated) {
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

  /// Called when no pose is detected in the current frame.
  Map<String, String> processNoPoseFrame() {
    resultIssues.feedback.clear();
    _syncPresenceState(hasPose: false);
    _populateBaseDebugData();
    debugData['personRatio'] =
        _personDetector.lastPersonRatio.toStringAsFixed(3);
    debugData['personScore'] = _personDetector.presenceScore.toStringAsFixed(3);
    debugData['personDetected'] = _personDetector.personDetected;
    debugData['isPaused'] = _isPaused;

    if (exerciseState == ExerciseState.completed) {
      return {'Result': 'Hoàn thành! $repCount reps'};
    }

    if (exerciseState == ExerciseState.notActivated) {
      resultIssues.feedback['System'] = _personConfirmed
          ? 'Giữ toàn thân trong khung hình để bắt đầu.'
          : 'Đang tìm người... Vui lòng đứng trong khung hình.';
    } else if (_isPaused || !_personDetector.personDetected) {
      resultIssues.feedback['System'] =
          '⏸ Tạm dừng — Quay lại khung hình để tiếp tục';
    } else {
      resultIssues.feedback['System'] =
          'Giữ toàn thân trong khung hình để AI theo dõi ổn định hơn.';
    }

    return Map<String, String>.from(resultIssues.feedback);
  }

  /// Async person detection — call from camera stream handler.
  Future<void> runPersonDetection(InputImage inputImage) async {
    if (exerciseState == ExerciseState.completed) return;

    await _personDetector.detect(inputImage);
  }

  /// Call when exercise screen is disposed to free native resources.
  Future<void> disposeDetectors() async {
    await _personDetector.close();
  }

  void _populateBaseDebugData() {
    debugData['exerciseState'] = exerciseState.toString().split('.').last;
    debugData['cameraFacing'] = cameraFacing.toString().split('.').last;
    debugData['personConfirmed'] = _personConfirmed;
  }

  void _syncPresenceState({required bool hasPose}) {
    final now = DateTime.now();
    final segmentationPresent = _personDetector.personDetected;
    final presentNow = hasPose || segmentationPresent;

    if (exerciseState == ExerciseState.notActivated) {
      if (!_personConfirmed) {
        if (presentNow) {
          _personSeenSince ??= now;
          if (now.difference(_personSeenSince!) >= _PERSON_CONFIRM_DURATION) {
            _personConfirmed = true;
          }
        } else {
          _personSeenSince = null;
        }
      } else if (!presentNow) {
        _personConfirmed = false;
        _personSeenSince = null;
        _holdStillStartedAt = null;
      }
      return;
    }

    if (exerciseState != ExerciseState.activated) return;

    if (presentNow) {
      _personLostSince = null;
      if (_isPaused) {
        _resumePresenceSince ??= now;
        if (now.difference(_resumePresenceSince!) >=
            _PERSON_RESUME_CONFIRM_DURATION) {
          _isPaused = false;
        }
      } else {
        _resumePresenceSince = now;
      }
      return;
    }

    _resumePresenceSince = null;
    _personLostSince ??= now;
    if (!_isPaused && now.difference(_personLostSince!) >= _PERSON_LOST_GRACE) {
      _isPaused = true;
    }
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
     STATE MACHINE — Hold-Still Activation (universal)
     
     User gets into valid position → holds for 3s → exercise starts.
     Each exercise defines "valid position" via isInStartPosition().
     ----------------------------------------------------------------------- */

  void checkExerciseState(
    Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
    ExerciseState currentState, {
    double? scaleFactor,
  }) {
    switch (currentState) {
      case ExerciseState.notActivated:
        final inPosition = isInStartPosition(
          smoothedLandmarks,
          cameraFacing,
          scaleFactor,
        );
        final now = DateTime.now();

        if (inPosition) {
          _holdStillStartedAt ??= now;
          final elapsed = now.difference(_holdStillStartedAt!);
          final remaining = (HOLD_STILL_REQUIRED_DURATION.inMilliseconds -
                  elapsed.inMilliseconds) /
              1000.0;
          debugData['holdStill'] = '${remaining.toStringAsFixed(1)}s';

          if (elapsed >= HOLD_STILL_REQUIRED_DURATION) {
            exerciseState = ExerciseState.activated;
            _holdStillStartedAt = null;
            onExerciseActivated();
          } else {
            resultIssues.feedback['System'] =
                'Giữ yên... ${remaining.clamp(0.0, 99.0).toStringAsFixed(0)}s';
          }
        } else {
          if (_holdStillStartedAt != null) {
            debugData['holdStill'] = 'reset';
          }
          _holdStillStartedAt = null;
          resultIssues.feedback['System'] = 'Vào tư thế và giữ yên để bắt đầu';
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
     ABSTRACT METHODS & LIFECYCLE HOOKS
     ----------------------------------------------------------------------- */

  void onExerciseActivated() {}

  bool requestStop();

  String? checkSafety(
    Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
    CameraFacing cameraFacing,
  );

  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
      CameraFacing cameraFacing, double? scaleFactor);

  /// Define what "ready position" looks like for this exercise.
  /// Called every frame during notActivated state.
  /// Return true if user is in valid starting position.
  bool isInStartPosition(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing facing,
    double? scaleFactor,
  );

  /* -----------------------------------------------------------------------
     UI BRIDGE
     ----------------------------------------------------------------------- */
  String get exerciseName;
  String get currentPhaseKey;
  String get currentPhaseLabel;
}
