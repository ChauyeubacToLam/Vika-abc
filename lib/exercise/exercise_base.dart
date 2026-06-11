/* =========================================================================
      ExerciseBase: abstract base class for all exercises. Centralizes common
      logic such as activation, person detection, orientation detection, and
      rep counting. Subclasses implement specific exercises by overriding the
      abstract methods at the bottom of this file.
      ========================================================================= */

// ignore_for_file: constant_identifier_names

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/pose/vika_pose_landmark.dart';
import 'package:vika/pose/vika_image_orientation.dart';
import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/person_detector.dart';
import '../utils/pose_smoother.dart';
import '../utils/pose_math_helpers.dart';
import "../utils/frame_buffer.dart";
import "../utils/exercise_logger.dart";
import '../debug/debug_types.dart';
import '../debug/tracked_metric.dart';
import '../services/viettel_tts_service.dart';
import '../pose/presence_anomaly_detector.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' show Size;

// --- Constants ---

const double FRONT_FACING_SHOULDER_THRESHOLD = 0.57;
const double SIDE_FACING_SHOULDER_THRESHOLD = 0.35;

// --- Enums ---

enum ExerciseState { notActivated, activated, completed }

enum CameraFacing { front, left, right, angled, undefined }

enum AngleChange { increasing, decreasing, stable }

abstract class ExerciseVoiceCoach {
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  });

  void dispose();
}

// --- Result Tracking ---

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

// --- ExerciseBase ---
//
// Abstract base class for all fitness exercises.
// Activation: user holds valid position for 3s → exercise begins.
// Each subclass overrides isInStartPosition() to define "ready" pose.

abstract class ExerciseBase {
  // Logger
  ExerciseLogger logger = ExerciseLogger();
  // Core state
  late PoseSmoother poseSmoother;
  int repCount = 0;

  /// Probability the landmark actually exists in the predicted skeleton.
  /// Drops cleanly when a person leaves frame; stays high for legitimately
  /// occluded landmarks such as the back leg in side-view squats.
  static const double MIN_PRESENCE = 0.7;

  /// Average presence below this threshold may indicate a faulty pose or that the
  /// person is not fully in frame.
  static const double AVG_LOW_PRESENCE_THRESHOLD = 0.35;

  /// Probability the landmark is unoccluded given that it exists.
  /// Used only as a secondary gate to reject fully extrapolated landmarks.
  static const double MIN_VISIBILITY = 0.3;

  /// Diagnostic-only bypass for auto-pause and pose-event backpressure.
  /// Keep false in production; enabling this disables pause paths while
  /// collecting continuity diagnostics.
  static const bool kDiagnosticMode = false;

  /// Master toggle for landscape orientation support across pose pipeline.
  /// When false, all paths fall through to portrait behavior identical to
  /// pre-spec production.
  static const bool kLandscapeRotationEnabled = true;

  /// Device orientations under which this exercise is designed to work.
  /// Defaults to portrait. Floor, prone, and seated exercises should override
  /// this with the tested orientations as they are added.
  ///
  /// Convention for future floor/prone/seated work such as Cobra, Sphinx,
  /// Seated Forward Fold, or Butterfly: declare both supported landscape
  /// orientations once the exercise metrics and framing are validated there.
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{VikaImageOrientation.portrait};

  // Trigger segmentation
  bool _wasPoseAnomaly = false;
  bool _wasPoseFrameEdgeRisk = false;
  bool _wasPoseLowPresence = false;
  bool _wasNoLandmarks = false;
  final PresenceAnomalyDetector _posePresenceDetector =
      PresenceAnomalyDetector();

  static bool isLandmarkConfident(PoseLandmark landmark) {
    return landmark.presence >= MIN_PRESENCE &&
        landmark.visibility >= MIN_VISIBILITY;
  }

  // Voice Service
  final ViettelTTSService ttsService = ViettelTTSService();

  // Scale factor (shoulder-to-hip distance)
  double scaleFactor = 1.0;

  // Frame buffer
  FrameBuffer frameBuffer = FrameBuffer();

  // Centralized per-frame timestamp (set once at the start of each frame)
  DateTime frameTimestamp = DateTime.now();
  int get frameTimestampMs => frameTimestamp.millisecondsSinceEpoch;

  List<Map<bool, Map<String, Map<String, String>>>> setFeedback = [];
  ResultIssues resultIssues = ResultIssues();

  ExerciseState exerciseState = ExerciseState.notActivated;
  CameraFacing cameraFacing = CameraFacing.front;
  DebugMode debugMode = DebugMode.off;
  bool correctForm = true;
  double frontFacingRatio = 1.0;

  Map<String, dynamic> debugData = {};
  late final TrackedMetric _exerciseDebugTracker =
      TrackedMetric(_ExerciseDebugMetricSource(this));

  List<TrackedMetric> get trackedDebugMetrics =>
      List<TrackedMetric>.unmodifiable([_exerciseDebugTracker]);

  bool get isDebugModeActive => debugMode != DebugMode.off;

  // Orientation debouncer
  StickyDebouncer leftRightDebouncer = StickyDebouncer(requiredFrames: 5);

  // -- FPS Tracking --
  DateTime? _lastFrameTime;
  double _currentFps = 30.0;

  double get currentFps => _currentFps;
  double get fpsRatio => _currentFps / 30.0;

  // Person detection (selfie segmentation)
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

  bool get isPaused => _isPaused;

  /// Manually pause the exercise (e.g. user tapped pause button).
  void manualPause() {
    if (exerciseState != ExerciseState.activated) return;
    _isPaused = true;
  }

  /// Manually resume after a manual pause.
  void manualResume() {
    _isPaused = false;
    _resumePresenceSince = DateTime.now();
    _personLostSince = null;
    _resetPresenceDetectors();
    unawaited(_personDetector.triggerCheck(reason: 'manual_resume'));
  }

  double get personPresenceScore => _personDetector.presenceScore;

  // Hold-still activation
  DateTime? _holdStillStartedAt;
  static const Duration HOLD_STILL_REQUIRED_DURATION = Duration(seconds: 3);

  /// Progress 0.0–1.0 for hold-still countdown UI. Null if not in countdown.
  double? get activationProgress {
    if (exerciseState != ExerciseState.notActivated) return null;
    if (!_personConfirmed) return null;
    if (_holdStillStartedAt == null) return null;
    final elapsed = frameTimestamp.difference(_holdStillStartedAt!);
    return (elapsed.inMilliseconds /
            HOLD_STILL_REQUIRED_DURATION.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  ExerciseBase() {
    poseSmoother = PoseSmoother(minCutoff: 0.5, beta: 0.005);
  }

  // --- Main Pipeline ---

  List<dynamic>? processPose(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    InputImage? inputImage,
    Size? imageSize,
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
    frameTimestamp = now; // for the person detection

    resultIssues.feedback.clear();

    final smoothedLandmarks = poseSmoother.smoothing(landmarks);

    // Pose returned after a no-landmark run. Ask segmentation for a fresh frame
    // before any paused/not-confirmed early return can block this path.
    if (_wasNoLandmarks) {
      unawaited(_personDetector.triggerCheck(reason: 'pose_returned'));
      _wasNoLandmarks = false;
    }

    _syncPresenceState(hasPose: true);

    // debugData['hasPose'] = true;
    // debugData['personRatio'] = _personDetector.lastPersonRatio;
    // debugData['personSoftRatio'] = _personDetector.lastSoftPersonRatio;
    // debugData['personSmoothedRatio'] = _personDetector.smoothedPersonRatio;
    // debugData['personSmoothedSoftRatio'] =
    //     _personDetector.smoothedSoftPersonRatio;
    // debugData['personScore'] = _personDetector.presenceScore;
    // debugData['personDetected'] = _personDetector.personDetected;
    // debugData['personPresent'] = _personDetector.personDetected;
    // debugData['segIntervalMs'] =
    //     _personDetector.configuredMinProcessIntervalMs ?? '-';
    // debugData['segEvents'] = _personDetector.segmentationEventCount;
    // debugData['segEventAgeMs'] =
    //     _personDetector.lastSegmentationEventAgeMs ?? '-';
    // debugData['segTriggerCounts'] = _personDetector.triggerCountByReason;
    // debugData['isPaused'] = _isPaused;

    // Person detection — only before activation
    if (exerciseState == ExerciseState.notActivated && !_personConfirmed) {
      final stableFor = _personSeenSince == null
          ? 0
          : frameTimestamp.difference(_personSeenSince!).inMilliseconds;
      if (isDebugModeActive) {
        debugData['personStableMs'] = stableFor;
      }

      if (!_personConfirmed) {
        resultIssues.feedback["System"] =
            "Đang tìm người... Vui lòng đứng trong khung hình.";
        _populateBaseDebugData();

        _trackDebugFrame();
        return [repCount, resultIssues.feedback];
      }
    }

    // Presence re-check during active exercise
    if (exerciseState == ExerciseState.activated) {
      if (_isPaused) {
        unawaited(_personDetector.triggerCheck(reason: 'paused_pose_present'));
        resultIssues.feedback["System"] =
            "⏸ Tạm dừng — Quay lại khung hình để tiếp tục";
        _populateBaseDebugData();
        _trackDebugFrame();
        return [repCount, resultIssues.feedback];
      }
    }

    final avgPosePresence = _computeAvgPresence(smoothedLandmarks);
    final poseLowPresence = avgPosePresence < AVG_LOW_PRESENCE_THRESHOLD;
    if (exerciseState == ExerciseState.activated &&
        poseLowPresence &&
        !_wasPoseLowPresence) {
      unawaited(_personDetector.triggerCheck(reason: 'pose_low_presence'));
    }
    _wasPoseLowPresence = poseLowPresence;

    final poseFrameEdgeRisk =
        _isPoseFrameEdgeRisk(smoothedLandmarks, imageSize: imageSize);
    if (exerciseState == ExerciseState.activated &&
        poseFrameEdgeRisk &&
        !_wasPoseFrameEdgeRisk) {
      unawaited(_personDetector.triggerCheck(reason: 'pose_frame_edge'));
    }
    _wasPoseFrameEdgeRisk = poseFrameEdgeRisk;

    _posePresenceDetector.update(avgPosePresence);

    // Trigger seg on anomaly transition (false -> true).
    final nowAnomaly = _posePresenceDetector.isAnomalyConfirmed;
    if (nowAnomaly && !_wasPoseAnomaly) {
      unawaited(_personDetector.triggerCheck(reason: 'pose_anomaly'));
    }
    _wasPoseAnomaly = nowAnomaly;

    // Auto-detect orientation
    cameraFacing = detectCameraFacing(smoothedLandmarks);

    // Safety check (subclass logic)
    final safetyError = checkSafety(smoothedLandmarks);
    if (safetyError != null) {
      resultIssues.feedback["System"] = safetyError;
      _populateBaseDebugData();
      _trackDebugFrame();
      return [repCount, resultIssues.feedback];
    }

    // Calculate scale factor (shoulder-to-hip distance)
    calScaleFacrtor(smoothedLandmarks);

    // State machine
    checkExerciseState(smoothedLandmarks, exerciseState);

    _populateBaseDebugData();
    // debugData['posePresenceBaseline'] = _posePresenceDetector.baseline;
    // debugData['posePresenceRecent'] = _posePresenceDetector.recent;
    // debugData['posePresenceDelta'] = _posePresenceDetector.currentDelta;
    // debugData['posePresenceAnomaly'] = _posePresenceDetector.isAnomalyConfirmed;
    // debugData['poseLowPresence'] = poseLowPresence;
    // debugData['poseFrameEdgeRisk'] = poseFrameEdgeRisk;
    // debugData['personPresent'] = _personDetector.personDetected;
    // debugData['segIntervalMs'] =
    //     _personDetector.configuredMinProcessIntervalMs ?? '-';
    // debugData['segEvents'] = _personDetector.segmentationEventCount;
    // debugData['segEventAgeMs'] =
    //     _personDetector.lastSegmentationEventAgeMs ?? '-';
    // debugData['segTriggerCounts'] = _personDetector.triggerCountByReason;
    // debugData['scaleFactor'] = scaleFactor;

    if (exerciseState == ExerciseState.activated) {
      checkingPose(smoothedLandmarks);
      _trackDebugFrame();
      if (exerciseState == ExerciseState.activated && requestStop()) {
        exerciseState = ExerciseState.completed;
        onSetComplete();
      }
      return exerciseState == ExerciseState.completed
          ? getSetFeedback()
          : getRepCountAndFeedback();
    } else if (exerciseState == ExerciseState.completed) {
      _trackDebugFrame();
      return getSetFeedback();
    }

    _trackDebugFrame();
    return [repCount, resultIssues.feedback];
  }

  /// Called when no pose is detected in the current frame.
  Map<String, String> processNoPoseFrame() {
    frameTimestamp = DateTime.now();
    resultIssues.feedback.clear();

    // Ask segmentation to catch up immediately when pose disappears but the
    // cached segmentation state still says a person is present.
    final hadLandmarksLastFrame = !_wasNoLandmarks;
    if (hadLandmarksLastFrame || _personDetector.personDetected) {
      unawaited(
        _personDetector.triggerCheck(
          reason: hadLandmarksLastFrame
              ? 'no_landmarks'
              : 'no_landmarks_stale_present',
        ),
      );
    }
    _wasNoLandmarks = true;
    _wasPoseAnomaly =
        false; // reset; if pose returns and is anomalous it'll re-trigger
    _wasPoseLowPresence = false;
    _wasPoseFrameEdgeRisk = false;

    _syncPresenceState(hasPose: false);
    _populateBaseDebugData();

    // debugData['hasPose'] = false;
    // debugData['personRatio'] = _personDetector.lastPersonRatio;
    // debugData['personSoftRatio'] = _personDetector.lastSoftPersonRatio;
    // debugData['personSmoothedRatio'] = _personDetector.smoothedPersonRatio;
    // debugData['personSmoothedSoftRatio'] =
    //     _personDetector.smoothedSoftPersonRatio;
    // debugData['personScore'] = _personDetector.presenceScore;
    // debugData['personDetected'] = _personDetector.personDetected;
    // debugData['personPresent'] = _personDetector.personDetected;
    // debugData['segIntervalMs'] =
    //     _personDetector.configuredMinProcessIntervalMs ?? '-';
    // debugData['segEvents'] = _personDetector.segmentationEventCount;
    // debugData['segEventAgeMs'] =
    //     _personDetector.lastSegmentationEventAgeMs ?? '-';
    // debugData['segTriggerCounts'] = _personDetector.triggerCountByReason;
    // debugData['isPaused'] = _isPaused;

    if (exerciseState == ExerciseState.completed) {
      _trackDebugFrame();
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

    _trackDebugFrame();
    return Map<String, String>.from(resultIssues.feedback);
  }

  /// Async person detection — call from camera stream handler.
  Future<void> runPersonDetection([InputImage? inputImage]) async {
    if (exerciseState == ExerciseState.completed) return;
    await _personDetector.detect(inputImage);
  }

  /// Free native resources on dispose.
  Future<void> disposeDetectors() async {
    await _personDetector.close();
  }

  ExerciseVoiceCoach? createVoiceCoach() => _PhaseInstructionVoiceCoach();

  void _populateBaseDebugData() {
    // debugData['exerciseState'] = exerciseState.toString().split('.').last;
    // debugData['cameraFacing'] = cameraFacing.toString().split('.').last;
    // debugData['personConfirmed'] = _personConfirmed;
  }

  void _trackDebugFrame() {
    if (!isDebugModeActive) return;
    _exerciseDebugTracker.onTick(frameTimestampMs);
  }

  void _syncPresenceState({required bool hasPose}) {
    final now = frameTimestamp;
    final presentNow = _personDetector.personDetected;

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
          _resetPresenceDetectors();
        }
      } else {
        _resumePresenceSince = now;
      }
      return;
    }

    _resumePresenceSince = null;
    _personLostSince ??= now;
    if (!_isPaused &&
        now.difference(_personLostSince!) >= _PERSON_LOST_GRACE &&
        !kDiagnosticMode) {
      _isPaused = true;
      _resetPresenceDetectors();
    }
  }

  // --- Orientation Detection ---

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

  // --- Helpers ---

  double calScaleFacrtor(
      Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final ls = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rs = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final lh = smoothedLandmarks[PoseLandmarkType.leftHip];
    final rh = smoothedLandmarks[PoseLandmarkType.rightHip];
    if (ls != null && rs != null && lh != null && rh != null) {
      final shoulderMidX = (ls.x + rs.x) / 2;
      final shoulderMidY = (ls.y + rs.y) / 2;
      final hipMidX = (lh.x + rh.x) / 2;
      final hipMidY = (lh.y + rh.y) / 2;
      final dx = shoulderMidX - hipMidX;
      final dy = shoulderMidY - hipMidY;
      scaleFactor = math.sqrt(dx * dx + dy * dy);
    }
    return scaleFactor;
  }

  void _resetPresenceDetectors() {
    _posePresenceDetector.reset();
    _wasPoseAnomaly = false;
    _wasPoseLowPresence = false;
    _wasPoseFrameEdgeRisk = false;
    _wasNoLandmarks = false;
  }

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

  double _computeAvgPresence(
      Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (smoothedLandmarks.isEmpty) return 0.0;
    double totalPresence = 0.0;
    for (final landmark in smoothedLandmarks.values) {
      totalPresence += landmark.presence;
    }
    return totalPresence / smoothedLandmarks.length;
  }

  bool _isPoseFrameEdgeRisk(
    Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks, {
    required Size? imageSize,
  }) {
    if (imageSize == null || imageSize == Size.zero) return false;
    if (imageSize.width <= 0 || imageSize.height <= 0) return false;

    final marginX = imageSize.width * 0.04;
    final marginY = imageSize.height * 0.04;
    var visibleCount = 0;
    var edgeCount = 0;
    var outsideCount = 0;

    for (final landmark in smoothedLandmarks.values) {
      if (landmark.presence < 0.25 && landmark.visibility < 0.25) {
        continue;
      }
      visibleCount += 1;

      final outside = landmark.x < 0 ||
          landmark.x > imageSize.width ||
          landmark.y < 0 ||
          landmark.y > imageSize.height;
      if (outside) {
        outsideCount += 1;
        continue;
      }

      if (landmark.x <= marginX ||
          landmark.x >= imageSize.width - marginX ||
          landmark.y <= marginY ||
          landmark.y >= imageSize.height - marginY) {
        edgeCount += 1;
      }
    }

    if (visibleCount < 8) return false;
    return outsideCount >= 2 || edgeCount >= 5;
  }

  List<dynamic> getRepCountAndFeedback() => [repCount, resultIssues.feedback];

  List<dynamic> getSetFeedback() => setFeedback;

  /// Hook for unifying voice feedback on rep completion
  void speakRepCompletion({
    required String? nextPhaseVoice,
    required bool correctForm,
    bool countRep = true,
  }) {
    if (countRep) {
      ttsService.speak(repCount.toString());
    }

    if (correctForm) {
      ttsService.speak("Tốt lắm");
    }

    if (!requestStop() && nextPhaseVoice != null) {
      ttsService.speak(nextPhaseVoice);
    }
  }

  // --- State Machine (Hold-Still Activation) ---

  void checkExerciseState(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
      ExerciseState currentState) {
    switch (currentState) {
      case ExerciseState.notActivated:
        final inPosition = isInStartPosition(smoothedLandmarks);
        final now = frameTimestamp;

        if (inPosition) {
          _holdStillStartedAt ??= now;
          final elapsed = now.difference(_holdStillStartedAt!);
          final remaining = (HOLD_STILL_REQUIRED_DURATION.inMilliseconds -
                  elapsed.inMilliseconds) /
              1000.0;

          if (elapsed >= HOLD_STILL_REQUIRED_DURATION) {
            exerciseState = ExerciseState.activated;
            _holdStillStartedAt = null;
            _resetPresenceDetectors();
            unawaited(_personDetector.useActivatedCadence());
            onExerciseActivated();
          } else {
            resultIssues.feedback['System'] =
                'Giữ yên... ${remaining.clamp(0.0, 99.0).toStringAsFixed(0)}s';
          }
        } else {
          if (_holdStillStartedAt != null) {}
          _holdStillStartedAt = null;
          resultIssues.feedback['System'] = 'Vào tư thế và giữ yên để bắt đầu';
        }
        break;

      case ExerciseState.activated:
        if (requestStop()) {
          exerciseState = ExerciseState.completed;
          ttsService.speak("Hoàn thành bài tập");
          onSetComplete();
        }
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

  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks);

  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks);

  /// Return true if user is in valid starting position.
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks);

  void onSetComplete();

  // --- UI Bridge ---

  String get exerciseName;
  String get currentPhaseKey;
  String get currentPhaseLabel;
}

class _ExerciseDebugMetricSource implements DebugMetricSource {
  const _ExerciseDebugMetricSource(this.exercise);

  final ExerciseBase exercise;

  @override
  String get name => exercise.exerciseName;

  @override
  String? get nameVi => null;

  @override
  Map<String, dynamic> get debugData => exercise.debugData;

  @override
  double? get value => exercise.currentFps;

  @override
  ThresholdBand? get threshold =>
      const ThresholdBand(warningBelow: 24, faultBelow: 18);

  @override
  MetricStatus get status {
    if (exercise.currentFps < 18) return MetricStatus.fault;
    if (exercise.currentFps < 24) return MetricStatus.near;
    return MetricStatus.pass;
  }

  @override
  bool get devOnly => false;
}

class _PhaseInstructionVoiceCoach implements ExerciseVoiceCoach {
  static const int _phaseCueMinGapMs = 450;

  String? _lastPhasePhrase;
  int _lastPhaseCueAtMs = 0;
  int _lastRepCount = 0;
  bool _didAnnounceReady = false;
  bool _didAnnounceSetComplete = false;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final repIncreased = repCount > _lastRepCount;

    if (exercise.exerciseState == ExerciseState.completed) {
      if (repIncreased) {
        exercise.ttsService.clearPendingButKeepCurrent();
        exercise.ttsService.speak('$repCount');
      }
      if (!_didAnnounceSetComplete) {
        exercise.ttsService.clearPendingButKeepCurrent();
        exercise.ttsService.speak('Hoàn thành bài tập');
        _didAnnounceSetComplete = true;
      }
      _lastPhasePhrase = null;
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastPhasePhrase = null;
      _lastRepCount = repCount;
      return;
    }

    if (!_didAnnounceReady) {
      exercise.ttsService.clearQueue();
      exercise.ttsService.speak('Sẵn sàng');
      _didAnnounceReady = true;
    }

    if (repIncreased) {
      exercise.ttsService.clearPendingButKeepCurrent();
      exercise.ttsService.speak('$repCount');
      _lastRepCount = repCount;
      _lastPhasePhrase = null;
      return;
    }

    final phasePhrase = _phasePhraseFor(exercise);
    if (phasePhrase == null || phasePhrase == _lastPhasePhrase) {
      _lastRepCount = repCount;
      return;
    }

    if (nowMs - _lastPhaseCueAtMs >= _phaseCueMinGapMs) {
      exercise.ttsService.speak(phasePhrase);
      _lastPhasePhrase = phasePhrase;
      _lastPhaseCueAtMs = nowMs;
    }
    _lastRepCount = repCount;
  }

  String? _phasePhraseFor(ExerciseBase exercise) {
    final phaseInstructions =
        exercise.resultIssues.instructions[exercise.currentPhaseKey];
    final status = phaseInstructions?['Status'];
    final phrase =
        status == null || status.isEmpty ? exercise.currentPhaseLabel : status;
    return _normalizePhrase(phrase);
  }

  String? _normalizePhrase(String phrase) {
    final value = phrase.trim();
    if (value.isEmpty) return null;

    if (value.contains('Going Down')) return 'Xuống';
    if (value.contains('Push Up') || value.contains('Đứng lên')) {
      return 'Đứng lên';
    }
    if (value.contains('Hold') || value.contains('Giữ')) return 'Giữ';
    if (value.contains('Sẵn sàng')) return 'Sẵn sàng';
    if (value.contains('Vào tư thế') || value.contains('giữ yên')) return null;

    return value;
  }

  @override
  void dispose() {
    _lastPhasePhrase = null;
  }
}
