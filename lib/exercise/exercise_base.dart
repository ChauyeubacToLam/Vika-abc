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
export 'package:vika/pose/vika_image_orientation.dart';
import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/person_detector.dart';
import '../utils/pose_smoother.dart';
import '../utils/pose_math_helpers.dart';
import "../utils/frame_buffer.dart";
import "../utils/exercise_logger.dart";
import '../debug/debug_types.dart';
import '../debug/tracked_metric.dart';
import '../services/generic_exercise_voice_assets.dart';
import '../services/queued_asset_voice_player.dart';
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

  String get setupOrientationIntroVoiceKey {
    final supportsPortrait =
        supportedOrientations.contains(VikaImageOrientation.portrait);
    final supportsLandscape =
        supportedOrientations.any((orientation) => orientation.isLandscape);

    if (supportsPortrait && !supportsLandscape) return 'common.thang_intro';
    if (supportsLandscape && !supportsPortrait) return 'common.ngang_intro';
    return supportsPortrait ? 'common.thang_intro' : 'common.ngang_intro';
  }

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
  final Stopwatch _sessionStopwatch = Stopwatch();
  int get elapsedMs => _sessionStopwatch.elapsedMilliseconds;

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
  final Map<String, TrackedMetric> _debugDataTrackers = {};

  List<TrackedMetric> get trackedDebugMetrics =>
      List<TrackedMetric>.unmodifiable(
        [
          _exerciseDebugTracker,
          ..._currentDebugDataTrackers(),
        ],
      );

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

  ExerciseVoiceCoach? createVoiceCoach() => _GenericExerciseVoiceCoach();

  void _populateBaseDebugData() {
    // debugData['exerciseState'] = exerciseState.toString().split('.').last;
    // debugData['cameraFacing'] = cameraFacing.toString().split('.').last;
    // debugData['personConfirmed'] = _personConfirmed;
  }

  void _trackDebugFrame() {
    if (!isDebugModeActive) return;

    final seen = <TrackedMetric>{};
    for (final trackedMetric in trackedDebugMetrics) {
      if (seen.add(trackedMetric)) {
        trackedMetric.onTick(frameTimestampMs);
      }
    }
  }

  List<TrackedMetric> _currentDebugDataTrackers() {
    final activeKeys = <String>{};
    for (final entry in debugData.entries) {
      if (_debugDataMetricValue(entry.value) == null) continue;

      final key = entry.key;
      activeKeys.add(key);
      _debugDataTrackers.putIfAbsent(
        key,
        () => TrackedMetric(_DebugDataMetricSource(this, key)),
      );
    }

    _debugDataTrackers.removeWhere((key, _) => !activeKeys.contains(key));
    return _debugDataTrackers.values.toList(growable: false);
  }

  static double? _debugDataMetricValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is! String) return null;

    final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
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

  void onExerciseActivated() {
    _sessionStopwatch
      ..reset()
      ..start();
  }

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

  /// Live hold timer for exercises that require the user to hold a pose.
  ///
  /// Return null when the current phase is not an active hold so the camera UI
  /// can hide the shared hold timer.
  double? get liveHoldSeconds => null;

  /// Optional target used by the shared hold timer UI.
  double? get liveHoldTargetSeconds => null;
}

class HoldSecondsAccumulator {
  HoldSecondsAccumulator(Iterable<String> faultKeys) {
    for (final key in faultKeys) {
      _faultSeconds[key] = 0.0;
    }
  }

  static const int minFrameDeltaMs = 10;
  static const int maxFrameDeltaMs = 250;

  final Map<String, double> _faultSeconds = {};
  double _goodSeconds = 0.0;
  int? _lastHoldTickMs;

  double get goodSeconds => _goodSeconds;

  double faultSecondsFor(String key) => _faultSeconds[key] ?? 0.0;

  void reset() {
    _goodSeconds = 0.0;
    for (final key in _faultSeconds.keys) {
      _faultSeconds[key] = 0.0;
    }
    _lastHoldTickMs = null;
  }

  void resetTick() {
    _lastHoldTickMs = null;
  }

  void accumulate({
    required int elapsedMs,
    required Map<String, bool> faultingByKey,
    Iterable<String>? goodBlockingKeys,
  }) {
    for (final key in faultingByKey.keys) {
      _faultSeconds.putIfAbsent(key, () => 0.0);
    }

    final previous = _lastHoldTickMs;
    _lastHoldTickMs = elapsedMs;
    if (previous == null) return;

    final dtMs = elapsedMs - previous;
    if (dtMs < minFrameDeltaMs || dtMs > maxFrameDeltaMs) return;

    final seconds = dtMs / 1000.0;
    var hasFault = false;
    final goodBlockingSet = goodBlockingKeys?.toSet();
    var hasGoodBlockingFault = false;
    for (final entry in faultingByKey.entries) {
      if (!entry.value) continue;
      hasFault = true;
      if (goodBlockingSet == null || goodBlockingSet.contains(entry.key)) {
        hasGoodBlockingFault = true;
      }
      _faultSeconds[entry.key] = (_faultSeconds[entry.key] ?? 0.0) + seconds;
    }

    if (!hasFault || !hasGoodBlockingFault) {
      _goodSeconds += seconds;
    }
  }
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

class _DebugDataMetricSource implements DebugMetricSource {
  const _DebugDataMetricSource(this.exercise, this.key);

  final ExerciseBase exercise;
  final String key;

  @override
  String get name => 'debug.$key';

  @override
  String? get nameVi => null;

  @override
  Map<String, dynamic> get debugData => {key: exercise.debugData[key]};

  @override
  double? get value =>
      ExerciseBase._debugDataMetricValue(exercise.debugData[key]);

  @override
  ThresholdBand? get threshold => null;

  @override
  MetricStatus get status => MetricStatus.pass;

  @override
  bool get devOnly => true;
}

// ignore: unused_element
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

class _GenericAssetVoicePlayer {
  _GenericAssetVoicePlayer()
      : _player = QueuedAssetVoicePlayer(
          assetMap: GenericExerciseVoiceAssets.commonFiles,
          assetSourcePrefix: GenericExerciseVoiceAssets.assetSourcePrefix,
          assetBundlePrefix: GenericExerciseVoiceAssets.assetBundlePrefix,
          assetResolver: GenericExerciseVoiceAssets.resolveAsset,
          logTag: 'GenericExerciseVoice',
        );

  final QueuedAssetVoicePlayer _player;

  Future<void> speak(String text) => _player.speak(text);
  void clearQueue() => _player.clearQueue();
  void clearPendingButKeepCurrent() => _player.clearPendingButKeepCurrent();
  void dispose() => _player.dispose();
}

class _GenericExerciseVoiceCoach implements ExerciseVoiceCoach {
  static final Map<String, Map<String, int>> _previousSetFaultsBySlug = {};

  final _GenericAssetVoicePlayer _voicePlayer = _GenericAssetVoicePlayer();
  final Map<String, int> _setFaultCounts = {};
  final Set<String> _currentRepFaultIds = {};
  final Set<String> _liveFaultsSpokenThisRep = {};

  int _lastRepCount = 0;
  bool _currentRepHadFormFault = false;
  bool _didAnnounceReady = false;
  bool _didSpeakSetup = false;
  bool _didSpeakPreviousSetAdvice = false;
  bool _didAnnounceSetComplete = false;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final script =
        GenericExerciseVoiceAssets.scriptForExerciseName(exercise.exerciseName);
    final repIncreased = repCount > _lastRepCount;

    if (exercise.exerciseState == ExerciseState.completed) {
      if (!_didAnnounceSetComplete) {
        _voicePlayer.clearPendingButKeepCurrent();
        if (repIncreased) {
          _speakRepOutcome(script, repCount);
        }
        _voicePlayer.speak('common.exercise_complete');
        _previousSetFaultsBySlug[script.slug] = Map.of(_setFaultCounts);
        _didAnnounceSetComplete = true;
      }
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _speakSetup(exercise, script);
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastRepCount = repCount;
      return;
    }

    if (!_didAnnounceReady) {
      _voicePlayer.clearQueue();
      _voicePlayer.speak('common.ready');
      _didAnnounceReady = true;
      _speakPreviousSetAdviceIfNeeded(script);
    }

    if (_feedbackIndicatesFault(feedback)) {
      _currentRepHadFormFault = true;
    }
    final liveFaultId = _faultIdForFeedback(script, feedback);
    if (liveFaultId != null) {
      _currentRepFaultIds.add(liveFaultId);
    }

    if (repIncreased) {
      _voicePlayer.clearPendingButKeepCurrent();
      _speakRepOutcome(script, repCount);
      _lastRepCount = repCount;
      _currentRepFaultIds.clear();
      _liveFaultsSpokenThisRep.clear();
      _currentRepHadFormFault = false;
      return;
    }

    if (liveFaultId != null &&
        !_liveFaultsSpokenThisRep.contains(liveFaultId) &&
        _shouldSpeakLiveFault(feedback)) {
      _liveFaultsSpokenThisRep.add(liveFaultId);
      _setFaultCounts[liveFaultId] = (_setFaultCounts[liveFaultId] ?? 0) + 1;
      _voicePlayer.speak(script.faultKey(liveFaultId));
    }

    _lastRepCount = repCount;
  }

  void _speakSetup(
    ExerciseBase exercise,
    GenericExerciseVoiceScript script,
  ) {
    if (_didSpeakSetup) return;
    _voicePlayer.speak(exercise.setupOrientationIntroVoiceKey);
    _voicePlayer.speak(script.cueKey('setup_position'));
    _voicePlayer.speak(script.cueKey('active_intro'));
    _speakPreviousSetAdviceIfNeeded(script);
    _didSpeakSetup = true;
  }

  void _speakRepOutcome(GenericExerciseVoiceScript script, int repCount) {
    _voicePlayer.speak('$repCount');

    if (_currentRepFaultIds.isEmpty) {
      _voicePlayer.speak(
        _currentRepHadFormFault
            ? 'common.fix_pose'
            : script.cueKey(script.cleanCueId),
      );
      return;
    }

    final faultId = script.faultIds.firstWhere(
      _currentRepFaultIds.contains,
      orElse: () => _currentRepFaultIds.first,
    );
    _setFaultCounts[faultId] = (_setFaultCounts[faultId] ?? 0) + 1;
    _voicePlayer.speak(script.faultKey(faultId));
  }

  void _speakPreviousSetAdviceIfNeeded(GenericExerciseVoiceScript script) {
    if (_didSpeakPreviousSetAdvice) return;

    final previous = _previousSetFaultsBySlug[script.slug];
    if (previous == null || previous.isEmpty) return;

    final sorted = previous.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _voicePlayer.speak(script.cueKey('set_next_setup'));
    for (final entry in sorted.take(2)) {
      _voicePlayer.speak(script.setNextFaultKey(entry.key));
    }
    _didSpeakPreviousSetAdvice = true;
  }

  String? _faultIdForFeedback(
    GenericExerciseVoiceScript script,
    Map<String, String> feedback,
  ) {
    if (feedback.isEmpty || script.faultIds.isEmpty) return null;

    final entries =
        feedback.entries.where((entry) => !_isNonFaultFeedbackKey(entry.key));

    for (final entry in entries) {
      final keyText = _normalizeFaultKey(entry.key);
      for (final candidate in _candidateFaultIdsForKey(keyText)) {
        if (script.hasFault(candidate)) return candidate;
      }

      final valueText = _normalizeFaultText(entry.value);
      if (!_looksLikeFaultText(valueText)) continue;

      final entryText = _normalizeFaultText('${entry.key} ${entry.value}');
      for (final candidate in _candidateFaultIds(entryText)) {
        if (script.hasFault(candidate)) return candidate;
      }
    }
    return null;
  }

  bool _looksLikeFaultText(String text) {
    const correctivePhrases = [
      'giu got',
      'giu lung',
      'giu than',
      'giu hong',
      'giu goi',
      'giu vai',
      'giu tay',
      'giu co tay',
      'giu thang',
      'giu dau',
      'day ',
      'mo ',
      'doi ',
      'trung ',
      'tiep dat',
      'ha ',
      'xuong',
      'nang',
      'khong ',
      'can ',
      'thu ',
    ];
    const markers = [
      'fault',
      'error',
      'warning',
      'bad',
      'fix',
      'too ',
      'don',
      'not ',
      'miss',
      'low',
      'high',
      'lower',
      'higher',
      'raise',
      'drop',
      'slow',
      'fast',
      'lift',
      'collapse',
      'sag',
      'pike',
      'lean',
      'bend',
      'straighten',
      'unstable',
      'shallow',
      'sai',
      'chua',
      'thieu',
      'nong',
      'thap',
      'cao',
      'qua',
      'lech',
      'vo',
      'sup',
      'gap',
      'duoi',
      'chong',
      'cham',
      'nhanh',
    ];

    return correctivePhrases.any(text.contains) || markers.any(text.contains);
  }

  Iterable<String> _candidateFaultIds(String text) sync* {
    for (final candidate
        in _candidateFaultIdsForKey(_normalizeFaultKey(text))) {
      yield candidate;
    }

    if (text.contains('tempo') ||
        text.contains('speed') ||
        text.contains('fast') ||
        text.contains('slow') ||
        text.contains('cham') ||
        text.contains('nhanh') ||
        text.contains('toc do')) {
      yield 'tempo';
      yield 'speed';
      yield 'tempo_fast';
      yield 'tempo_slow';
      yield 'too_fast';
    }
    if (text.contains('too deep') ||
        text.contains('qua sau') ||
        text.contains('sau qua')) {
      yield 'too_deep';
      yield 'depth_deep';
    }
    if (text.contains('depth') ||
        text.contains('rom') ||
        text.contains('low') ||
        text.contains('shallow') ||
        text.contains('nong') ||
        text.contains('sau') ||
        text.contains('thap') ||
        text.contains('ha') ||
        text.contains('xuong')) {
      yield 'depth';
      yield 'rom';
      yield 'depth_shallow';
      yield 'takeoff_depth';
      yield 'landing_depth';
      yield 'rear_depth';
      yield 'squat_depth';
      yield 'amplitude';
    }
    if (text.contains('takeoff') ||
        text.contains('lay da') ||
        text.contains('bat nhay')) {
      yield 'takeoff_depth';
    }
    if (text.contains('landing') ||
        text.contains('tiep dat') ||
        text.contains('trung goi')) {
      yield 'landing_depth';
      if (text.contains('stiff') ||
          text.contains('cung') ||
          text.contains('thang')) {
        yield 'landing_stiff';
      }
    }
    if (text.contains('heel') || text.contains('got')) yield 'heel';
    if (text.contains('knee') || text.contains('goi')) {
      yield 'knee';
      yield 'knee_valgus';
      yield 'knee_angle';
      yield 'knee_extension';
      yield 'knee_hover';
      yield 'front_knee';
      yield 'back_knee';
      yield 'knees';
    }
    if (text.contains('arm') ||
        text.contains('wrist') ||
        text.contains('tay') ||
        text.contains('co tay')) {
      yield 'arms';
      yield 'arm_extension';
      yield 'extension';
      yield 'straight_arm';
      yield 'hand';
      yield 'wrist';
    }
    if (text.contains('elbow') || text.contains('khuyu')) {
      yield 'elbow';
      yield 'extension';
      yield 'arm_extension';
      yield 'setup_guard';
    }
    if (text.contains('leg') ||
        text.contains('ankle') ||
        text.contains('chan') ||
        text.contains('co chan')) {
      yield 'legs';
      yield 'leg';
      yield 'straight_leg';
      yield 'stable_limbs';
      yield 'elevation_leg';
      yield 'ankle';
      yield 'foot';
    }
    if (text.contains('hip') ||
        text.contains('pelvic') ||
        text.contains('hong') ||
        text.contains('chau')) {
      if (text.contains('high') ||
          text.contains('pike') ||
          text.contains('cao') ||
          text.contains('nang')) {
        yield 'pike';
        yield 'piked';
        yield 'hip_high';
      }
      if (text.contains('drop') ||
          text.contains('low') ||
          text.contains('thap') ||
          text.contains('sup')) {
        yield 'sag';
        yield 'sagging';
        yield 'trunk_sag';
        yield 'pelvic_drop';
      }
      yield 'hip';
      yield 'hip_extension';
      yield 'hip_rotation';
      yield 'hip_high';
      yield 'hip_thrust';
      yield 'pelvic';
      yield 'pelvic_drop';
    }
    if (text.contains('back') ||
        text.contains('trunk') ||
        text.contains('spine') ||
        text.contains('lumbar') ||
        text.contains('lung') ||
        text.contains('than') ||
        text.contains('cot song') ||
        text.contains('nguc')) {
      if (text.contains('sag') ||
          text.contains('drop') ||
          text.contains('low') ||
          text.contains('vo') ||
          text.contains('sup')) {
        yield 'sag';
        yield 'sagging';
        yield 'trunk_sag';
        yield 'back_sag';
      }
      if (text.contains('pike') ||
          text.contains('high') ||
          text.contains('cao') ||
          text.contains('nang')) {
        yield 'pike';
        yield 'piked';
        yield 'trunk_pike';
      }
      yield 'trunk';
      yield 'trunk_sag';
      yield 'trunk_pike';
      yield 'back_sag';
      yield 'back_arch';
      yield 'spine';
      yield 'lumbar';
      yield 'body_line';
      yield 'torso';
      yield 'chest';
    }
    if (text.contains('neck') ||
        text.contains('head') ||
        text.contains('ear') ||
        text.contains('dau')) {
      yield 'neck';
      yield 'head';
      yield 'cervical';
      yield 'neck_pull';
    }
    if (text.contains('shoulder') || text.contains('vai')) {
      yield 'shoulder';
      yield 'shrug';
    }
    if (text.contains('hand')) yield 'hand';
    if (text.contains('alternate') || text.contains('doi ben')) {
      yield 'alternate';
      yield 'alternating';
    }
    if (text.contains('same') ||
        text.contains('opposite') ||
        text.contains('cheo') ||
        text.contains('nguoc')) {
      yield 'opposite_side';
      yield 'cross_rom';
    }
    if (text.contains('still') ||
        text.contains('stable') ||
        text.contains('on dinh')) {
      yield 'stability';
      yield 'drift';
    }
    if (text.contains('setup') ||
        text.contains('guard') ||
        text.contains('tu the') ||
        text.contains('chi gap')) {
      yield 'setup';
      yield 'setup_guard';
      yield 'wall_guard';
    }
    if (text.contains('double')) yield 'double_knee';
    if (text.contains('momentum') || text.contains('jerk')) {
      yield 'momentum';
      yield 'jerking';
    }
  }

  Iterable<String> _candidateFaultIdsForKey(String key) sync* {
    if (key.isEmpty) return;
    yield key;

    switch (key) {
      case 'heel_lift':
        yield 'heel';
        break;
      case 'bent_straight_leg':
        yield 'straight_leg';
        break;
      case 'torso_lean':
        yield 'torso';
        yield 'trunk';
        break;
      case 'shallow_depth':
        yield 'depth_shallow';
        yield 'depth';
        break;
      case 'too_deep':
        yield 'depth_deep';
        break;
      case 'power':
        yield 'takeoff_depth';
        break;
      case 'back':
        yield 'trunk';
        yield 'torso';
        break;
      case 'knee':
        yield 'landing_stiff';
        yield 'landing_depth';
        yield 'knee';
        break;
      case 'error':
        yield 'too_fast';
        break;
    }
  }

  bool _feedbackIndicatesFault(Map<String, String> feedback) {
    final result = _normalizeFaultText(feedback['Result'] ?? '');
    if (result.contains('sai') ||
        result.contains('fix') ||
        result.contains('no count') ||
        result.contains('khong tinh') ||
        result.contains('chua tinh')) {
      return true;
    }

    return feedback.entries.any((entry) {
      if (_isNonFaultFeedbackKey(entry.key)) return false;
      return _looksLikeFaultText(_normalizeFaultText(entry.value));
    });
  }

  bool _isNonFaultFeedbackKey(String key) {
    final normalized = key.toLowerCase();
    return normalized == 'system' ||
        normalized == 'result' ||
        normalized == 'progress' ||
        normalized == 'status' ||
        normalized == 'phase';
  }

  String _normalizeFaultKey(String value) {
    final normalized = _normalizeFaultText(value)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized;
  }

  String _normalizeFaultText(String value) {
    var text = value.toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ả': 'a',
      'ã': 'a',
      'ạ': 'a',
      'ă': 'a',
      'ắ': 'a',
      'ằ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'ặ': 'a',
      'â': 'a',
      'ấ': 'a',
      'ầ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ậ': 'a',
      'é': 'e',
      'è': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ẹ': 'e',
      'ê': 'e',
      'ế': 'e',
      'ề': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ệ': 'e',
      'í': 'i',
      'ì': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ị': 'i',
      'ó': 'o',
      'ò': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ọ': 'o',
      'ô': 'o',
      'ố': 'o',
      'ồ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ộ': 'o',
      'ơ': 'o',
      'ớ': 'o',
      'ờ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ợ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ụ': 'u',
      'ư': 'u',
      'ứ': 'u',
      'ừ': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ự': 'u',
      'ý': 'y',
      'ỳ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'ỵ': 'y',
      'đ': 'd',
    };
    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text;
  }

  bool _shouldSpeakLiveFault(Map<String, String> feedback) {
    final result = _normalizeFaultText(feedback['Result'] ?? '');
    return result.contains('sai') ||
        result.contains('fix') ||
        result.contains('no count') ||
        result.contains('khong tinh') ||
        result.contains('chua tinh');
  }

  @override
  void dispose() {
    _currentRepFaultIds.clear();
    _liveFaultsSpokenThisRep.clear();
    _currentRepHadFormFault = false;
    _setFaultCounts.clear();
    _voicePlayer.clearQueue();
    _voicePlayer.dispose();
  }
}
