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
import '../utils/pose_smoother.dart';
import '../utils/pose_math_helpers.dart';
import '../utils/frame_buffer.dart';
import '../utils/exercise_logger.dart';
export 'package:vika/utils/hold_seconds_accumulator.dart';
import '../debug/debug_types.dart';
import '../services/generic_exercise_voice_assets.dart';
import '../services/queued_asset_voice_player.dart';
import '../services/viettel_tts_service.dart';
import 'dart:math' as math;
import 'presence_gate.dart';
import 'dart:async';
import 'dart:ui' show Size;

// --- Constants ---

const double FRONT_FACING_SHOULDER_THRESHOLD = 0.57;
const double SIDE_FACING_SHOULDER_THRESHOLD = 0.35;

/// Min |z-gap| between a left/right landmark pair before it counts as a vote
/// for one side. Below this the pair is treated as ambiguous (near-frontal
/// camera) and skipped in _isLeftSide().
const double SIDE_VOTE_Z_THRESHOLD = 0.01;

/// Adaptation rate for scaleFactor EMA while the exercise is activated.
/// At 0.1, a genuine mid-set camera shift converges in ~1-2 s; a single
/// occluded frame contributes ≤10 % → spike-resistant. Final value is set
/// during the curl_up device pass (see ADR + spec).
const double SCALE_EMA_ALPHA = 0.1;

// --- Enums ---

enum ExerciseState { notActivated, activated, completed }

enum CameraFacing { front, left, right, angled, undefined }

abstract class ExerciseVoiceCoach {
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  });

  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return Future<void>.value();
  }

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

  bool get isDebugModeActive => debugMode != DebugMode.off;

  // Orientation debouncer
  StickyDebouncer leftRightDebouncer = StickyDebouncer(requiredFrames: 5);

  // -- FPS Tracking --
  DateTime? _lastFrameTime;
  double _currentFps = 30.0;

  double get currentFps => _currentFps;
  double get fpsRatio => _currentFps / 30.0;

  // Presence / auto-pause / segmentation-trigger gate.
  final PresenceGate _gate = PresenceGate(diagnosticMode: kDiagnosticMode);

  bool get isPaused => _gate.isPaused;

  /// Manually pause the exercise (e.g. user tapped pause button).
  /// Allowed in any state — pausing pre-activation is odd but harmless, and
  /// the pause overlay always exposes a resume button so nobody gets stuck.
  void manualPause() {
    _gate.manualPause();
  }

  /// Manually resume after a manual pause.
  void manualResume() => _gate.manualResume(DateTime.now());

  double get personPresenceScore => _gate.presenceScore;

  // Hold-still activation
  DateTime? _holdStillStartedAt;
  static const Duration HOLD_STILL_REQUIRED_DURATION = Duration(seconds: 3);

  /// Progress 0.0–1.0 for hold-still countdown UI. Null if not in countdown.
  double? get activationProgress {
    if (exerciseState != ExerciseState.notActivated) return null;
    if (!_gate.personConfirmed) return null;
    if (_holdStillStartedAt == null) return null;
    final elapsed = frameTimestamp.difference(_holdStillStartedAt!);
    return (elapsed.inMilliseconds /
            HOLD_STILL_REQUIRED_DURATION.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  ExerciseBase() {
    poseSmoother = PoseSmoother(minCutoff: 0.5, beta: 0.005);
  }

  /// Maps the base's [ExerciseState] to the gate's [GatePhase] on each call.
  /// The gate defines its own phase enum (not this one) so it stays free of any
  /// exercise_base import — that's what breaks the otherwise-circular dependency.
  GatePhase get _gatePhase {
    switch (exerciseState) {
      case ExerciseState.notActivated:
        return GatePhase.seeking;
      case ExerciseState.activated:
        return GatePhase.active;
      case ExerciseState.completed:
        return GatePhase.done;
    }
  }

  /// Turns a gate block reason into the user-facing Vietnamese line. All copy
  /// lives here in the base, never in the gate — the gate is UI-language-free
  /// and returns enums only, so wording changes touch exactly one place.
  String _systemStringForBlock(GateBlock block) {
    switch (block) {
      case GateBlock.searching:
        return 'Đang tìm người... Vui lòng đứng trong khung hình.';
      case GateBlock.paused:
        return '⏸ Tạm dừng — Quay lại khung hình để tiếp tục';
    }
  }

  // --- Main Pipeline ---

  List<dynamic>? processPose(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    InputImage? inputImage,
    Size? imageSize,
  }) {
    // One wall-clock read per frame. `now` drives the FPS delta below;
    // `frameTimestamp` is the canonical frame clock every downstream stage reads
    // (gate confirm/pause timers, hold-still countdown, scale EMA). Same instant
    // by design — never call DateTime.now() again mid-frame or the timers desync.
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final deltaMs = now.difference(_lastFrameTime!).inMilliseconds;
      if (deltaMs > 0) {
        // Smoothed FPS = exponential moving average (90% history, 10% newest) so
        // a single slow frame doesn't jerk the value. fpsRatio (currentFps / 30)
        // then time-scales motion thresholds — e.g. glute_bridge multiplies its
        // rep velocity by fpsRatio so fast and slow devices count reps alike.
        final frameFps = 1000.0 / deltaMs;
        _currentFps = _currentFps * 0.9 + frameFps * 0.1;
      }
    }
    _lastFrameTime = now;
    frameTimestamp = now;

    resultIssues.feedback.clear();

    final smoothedLandmarks = poseSmoother.smoothing(landmarks);

    // Presence gate: one call per frame owns "is a real person reliably in
    // frame, should we auto-pause, when to poke segmentation." It returns a
    // verdict; the base only acts on it and never reaches into gate internals.
    final verdict = _gate.onPose(
      now: frameTimestamp,
      phase: _gatePhase,
      landmarks: smoothedLandmarks,
      imageSize: imageSize,
    );
    // The one cross-boundary coupling: when a confirmed person drops out during
    // seeking, the hold-still countdown (base-owned state) must reset too.
    if (verdict.personLostNow) _holdStillStartedAt = null;
    // proceed=false → gate blocked this frame (searching or paused). Base owns
    // the Vietnamese copy; the gate only names the reason via an enum.
    if (!verdict.proceed) {
      resultIssues.feedback['System'] = _systemStringForBlock(verdict.block!);
      return [repCount, resultIssues.feedback];
    }

    // Auto-detect orientation
    cameraFacing = detectCameraFacing(smoothedLandmarks);

    // Safety check (subclass logic)
    final safetyError = checkSafety(smoothedLandmarks);
    if (safetyError != null) {
      resultIssues.feedback["System"] = safetyError;
      return [repCount, resultIssues.feedback];
    }

    // Calibrate scale factor (shoulder-to-hip distance). Must stay here, before
    // checkExerciseState, so isInStartPosition reads a fresh value on this frame
    // (glute_bridge's start check consumes scaleFactor — moving this write after
    // that call would deadlock the hold gate at scaleFactor = 1.0 forever).
    _updateScaleFactor(smoothedLandmarks);
    // State machine
    checkExerciseState(smoothedLandmarks, exerciseState);

    if (exerciseState == ExerciseState.activated) {
      checkingPose(smoothedLandmarks);
      if (exerciseState == ExerciseState.activated && requestStop()) {
        exerciseState = ExerciseState.completed;
        onSetComplete();
      }
      return exerciseState == ExerciseState.completed
          ? getSetFeedback()
          : getRepCountAndFeedback();
    } else if (exerciseState == ExerciseState.completed) {
      return getSetFeedback();
    }

    return [repCount, resultIssues.feedback];
  }

  /// Called when ML Kit returns no skeleton this frame (person out of view,
  /// too dark, mid-transition). Still drives the gate: presence is decided by
  /// the segmentation detector's cached state, NOT by whether pose landmarks
  /// exist, so confirm/pause timers must keep ticking even with no skeleton.
  Map<String, String> processNoPoseFrame() {
    frameTimestamp = DateTime.now();
    resultIssues.feedback.clear();

    final verdict = _gate.onNoPose(now: frameTimestamp, phase: _gatePhase);
    if (verdict.personLostNow) _holdStillStartedAt = null;

    if (exerciseState == ExerciseState.completed) {
      return {'Result': 'Hoàn thành! $repCount reps'};
    }

    if (exerciseState == ExerciseState.notActivated) {
      resultIssues.feedback['System'] = _gate.personConfirmed
          ? 'Giữ toàn thân trong khung hình để bắt đầu.'
          : 'Đang tìm người... Vui lòng đứng trong khung hình.';
    } else if (_gate.isPaused || !_gate.personDetected) {
      resultIssues.feedback['System'] =
          '⏸ Tạm dừng — Quay lại khung hình để tiếp tục';
    } else {
      resultIssues.feedback['System'] =
          'Giữ toàn thân trong khung hình để AI theo dõi ổn định hơn.';
    }

    return Map<String, String>.from(resultIssues.feedback);
  }

  /// Async person detection — call from camera stream handler.
  Future<void> runPersonDetection([InputImage? inputImage]) async {
    if (exerciseState == ExerciseState.completed) return;
    await _gate.runDetection(inputImage);
  }

  /// Free native resources on dispose.
  Future<void> disposeDetectors() async => _gate.close();

  ExerciseVoiceCoach? createVoiceCoach() => _GenericExerciseVoiceCoach();

  /// Whether the generic coach may replay faults from the previous set while
  /// preparing the next one.
  bool get shouldReplayPreviousSetVoiceFaults => true;

  

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
      if (zDiff.abs() > SIDE_VOTE_Z_THRESHOLD) {
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

  /// Two-state calibration write.
  ///
  /// - notActivated: hard-write the current confident measurement each frame.
  ///   isInStartPosition needs a real scaleFactor on the very first frame it
  ///   runs (glute_bridge deadlocks otherwise); writing every confident frame
  ///   gives it that, and the final hard-write at activation seeds the EMA.
  /// - activated: slow EMA (SCALE_EMA_ALPHA = 0.1). Adapts to genuine mid-set
  ///   repositioning over ~1-2 s while refusing to spike on a single occluded
  ///   frame (that frame contributes ≤10 %).
  /// - completed: no-op — nothing reads scaleFactor post-set.
  ///
  /// Bad frames (null from _rawScale) never write in either state, so
  /// reuse-last-good is automatic and requires no extra flag or fallback.
  void _updateScaleFactor(
      Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final raw = _rawScale(smoothedLandmarks);
    if (raw == null) return; // not measurable this frame → keep prior value
    if (exerciseState == ExerciseState.notActivated) {
      scaleFactor = raw;
    } else if (exerciseState == ExerciseState.activated) {
      scaleFactor = SCALE_EMA_ALPHA * raw + (1 - SCALE_EMA_ALPHA) * scaleFactor;
    }
  }

  /// Side-aware shoulder→hip pixel distance, gated on isLandmarkConfident.
  ///
  /// PoseSmoother keeps every ML Kit landmark key — an occluded landmark
  /// arrives as a low-confidence entry with kept/hallucinated coordinates, not
  /// as a missing key. Gating on isLandmarkConfident (not != null) is what
  /// blocks the hallucinated far-side hip that was producing the 1.0-spike bug.
  ///
  /// - Side-facing (left/right): camera-side pair only. Requesting both sides
  ///   would always return null for glute bridge and curl-up whose far side is
  ///   legitimately occluded.
  /// - Front/angled/undefined: midpoints of both shoulders and both hips; all
  ///   four must be confident or the frame is skipped.
  ///
  /// Returns null when landmarks aren't confidently measurable this frame.
  double? _rawScale(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (cameraFacing == CameraFacing.left ||
        cameraFacing == CameraFacing.right) {
      final s = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder,
      );
      final h = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip,
      );
      if (s == null || h == null) return null;
      if (!isLandmarkConfident(s) || !isLandmarkConfident(h)) return null;
      return calculateDistance(s, h); // pose_math_helpers.dart, takes dynamic
    }
    // front / angled / undefined: midpoints — all four landmarks required
    final ls = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rs = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final lh = smoothedLandmarks[PoseLandmarkType.leftHip];
    final rh = smoothedLandmarks[PoseLandmarkType.rightHip];
    if (ls == null || rs == null || lh == null || rh == null) return null;
    if (!isLandmarkConfident(ls) || !isLandmarkConfident(rs) ||
        !isLandmarkConfident(lh) || !isLandmarkConfident(rh)) {
      return null;
    }
    // Midpoints aren't PoseLandmark objects, so calculateDistance can't be used;
    // inline the same sqrt formula it uses.
    final dx = (ls.x + rs.x) / 2 - (lh.x + rh.x) / 2;
    final dy = (ls.y + rs.y) / 2 - (lh.y + rh.y) / 2;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Returns the landmark on the camera-facing side. Only an explicit `right`
  /// facing returns the right landmark; every other facing (left/front/angled/
  /// undefined) falls through to the left landmark by design.
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
            _gate.onActivated();
            onExerciseActivated();
          } else {
            resultIssues.feedback['System'] =
                'Giữ yên... ${remaining.clamp(0.0, 99.0).toStringAsFixed(0)}s';
          }
        } else {
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
  Future<void> waitUntilIdle({required Duration timeout}) =>
      _player.waitUntilIdle(timeout: timeout);
  void clearQueue() => _player.clearQueue();
  void clearPendingButKeepCurrent() => _player.clearPendingButKeepCurrent();
  void dispose() => _player.dispose();
}

class _GenericExerciseVoiceCoach implements ExerciseVoiceCoach {
  static final Map<String, Map<String, int>> _previousSetFaultsBySlug = {};
  static const int _noCountCueCooldownMs = 1200;
  static const int _holdFaultCueCooldownMs = 2500;
  static const int _holdStallFramesBeforeCue = 4;
  static const double _holdProgressEpsilonSeconds = 0.05;

  final _GenericAssetVoicePlayer _voicePlayer = _GenericAssetVoicePlayer();
  final Map<String, int> _setFaultCounts = {};

  int _lastRepCount = 0;
  int _lastNoCountCueAtMs = 0;
  int _lastHoldFaultCueAtMs = 0;
  int _holdStallFrames = 0;
  int? _lastOutcomeRepNumber;
  double? _lastLiveHoldSeconds;
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
    final isHoldTimerExercise = exercise.liveHoldTargetSeconds != null;

    if (exercise.exerciseState == ExerciseState.completed) {
      if (!_didAnnounceSetComplete) {
        _voicePlayer.clearPendingButKeepCurrent();
        if (repIncreased) {
          final completedRepLog = _latestRepLog(exercise, repCount);
          final latestRepLog = _latestRepLogAnyNumber(exercise);
          if (completedRepLog != null &&
              completedRepLog.repNumber != _lastOutcomeRepNumber) {
            _speakRepLogOutcome(
              script: script,
              repLog: completedRepLog,
              includeCount: true,
            );
          } else if (isHoldTimerExercise &&
              latestRepLog != null &&
              latestRepLog.repNumber != _lastOutcomeRepNumber) {
            _speakRepLogOutcome(
              script: script,
              repLog: latestRepLog,
              includeCount: false,
            );
          } else if (completedRepLog == null && latestRepLog == null) {
            _speakUnknownRepOutcome(
              script: script,
              repCount: repCount,
              feedback: feedback,
            );
          }
        } else if (isHoldTimerExercise) {
          final latestRepLog = _latestRepLogAnyNumber(exercise);
          if (latestRepLog != null &&
              latestRepLog.repNumber != _lastOutcomeRepNumber) {
            _speakRepLogOutcome(
              script: script,
              repLog: latestRepLog,
              includeCount: false,
            );
          }
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
      _resetHoldProgressTracking();
      return;
    }

    if (!_didAnnounceReady) {
      _voicePlayer.speak('common.ready');
      _didAnnounceReady = true;
      _speakPreviousSetAdviceIfNeeded(exercise, script);
    }

    if (isHoldTimerExercise) {
      _handleHoldTimerProgress(
        script: script,
        exercise: exercise,
        feedback: feedback,
      );

      if (repIncreased && _latestRepLog(exercise, repCount) == null) {
        _lastRepCount = repCount;
        return;
      }
    }

    if (!repIncreased && _isNoCountFeedback(feedback)) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastNoCountCueAtMs >= _noCountCueCooldownMs) {
        _voicePlayer.clearPendingButKeepCurrent();
        _voicePlayer.speak('common.no_count');
        final faultId = _faultIdForFeedback(script, feedback);
        if (faultId != null) {
          _setFaultCounts[faultId] = (_setFaultCounts[faultId] ?? 0) + 1;
          _voicePlayer.speak(script.faultKey(faultId));
        } else if (_feedbackIndicatesFault(feedback)) {
          _voicePlayer.speak('common.fix_pose');
        }
        _lastNoCountCueAtMs = nowMs;
      }
      _lastRepCount = repCount;
      return;
    }

    if (repIncreased) {
      final completedRepLog = _latestRepLog(exercise, repCount);
      _voicePlayer.clearPendingButKeepCurrent();
      if (completedRepLog != null) {
        _speakRepLogOutcome(
          script: script,
          repLog: completedRepLog,
          includeCount: true,
        );
      } else {
        _speakUnknownRepOutcome(
          script: script,
          repCount: repCount,
          feedback: feedback,
        );
      }
      _lastRepCount = repCount;
      return;
    }

    _lastRepCount = repCount;
  }

  void _handleHoldTimerProgress({
    required GenericExerciseVoiceScript script,
    required ExerciseBase exercise,
    required Map<String, String> feedback,
  }) {
    final liveHoldSeconds = exercise.liveHoldSeconds;
    if (liveHoldSeconds == null) {
      _resetHoldProgressTracking();
      return;
    }

    final targetSeconds = exercise.liveHoldTargetSeconds;
    if (targetSeconds != null &&
        liveHoldSeconds >= targetSeconds - _holdProgressEpsilonSeconds) {
      _lastLiveHoldSeconds = liveHoldSeconds;
      _holdStallFrames = 0;
      return;
    }

    final previous = _lastLiveHoldSeconds;
    _lastLiveHoldSeconds = liveHoldSeconds;
    if (previous == null ||
        liveHoldSeconds > previous + _holdProgressEpsilonSeconds) {
      _holdStallFrames = 0;
      return;
    }

    _holdStallFrames++;
    if (_holdStallFrames < _holdStallFramesBeforeCue) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastHoldFaultCueAtMs < _holdFaultCueCooldownMs) {
      return;
    }

    final faultId = _faultIdForFeedback(script, feedback);
    if (faultId != null) {
      _voicePlayer.clearPendingButKeepCurrent();
      _speakFaultId(script, faultId);
      _lastHoldFaultCueAtMs = nowMs;
      return;
    }

    if (_feedbackIndicatesFault(feedback)) {
      _voicePlayer.clearPendingButKeepCurrent();
      _voicePlayer.speak('common.fix_pose');
      _lastHoldFaultCueAtMs = nowMs;
    }
  }

  void _resetHoldProgressTracking() {
    _lastLiveHoldSeconds = null;
    _holdStallFrames = 0;
  }

  void _speakSetup(
    ExerciseBase exercise,
    GenericExerciseVoiceScript script,
  ) {
    if (_didSpeakSetup) return;
    _voicePlayer.speak(exercise.setupOrientationIntroVoiceKey);
    _voicePlayer.speak(script.cueKey('setup_position'));
    _voicePlayer.speak(script.cueKey('active_intro'));
    _speakPreviousSetAdviceIfNeeded(exercise, script);
    _didSpeakSetup = true;
  }

  void _speakUnknownRepOutcome({
    required GenericExerciseVoiceScript script,
    required int repCount,
    required Map<String, String> feedback,
  }) {
    _lastOutcomeRepNumber = repCount;
    _voicePlayer.speak('$repCount');

    final faultId = _faultIdForFeedback(script, feedback);
    if (faultId != null) {
      _speakFaultId(script, faultId);
      return;
    }

    _voicePlayer.speak(
      _feedbackIndicatesFault(feedback) ? 'common.fix_pose' : 'common.correct',
    );
  }

  void _speakRepLogOutcome({
    required GenericExerciseVoiceScript script,
    required RepLog repLog,
    required bool includeCount,
  }) {
    _lastOutcomeRepNumber = repLog.repNumber;
    if (includeCount) {
      _voicePlayer.speak('${repLog.repNumber}');
    }

    if (repLog.correctForm) {
      _voicePlayer.speak('common.correct');
      return;
    }

    final faultIds = _faultIdsForRepLog(script, repLog);
    if (faultIds.isEmpty) {
      _voicePlayer.speak('common.fix_pose');
      return;
    }

    final faultId = script.faultIds.firstWhere(
      faultIds.contains,
      orElse: () => faultIds.first,
    );
    _speakFaultId(script, faultId);
  }

  void _speakFaultId(GenericExerciseVoiceScript script, String faultId) {
    _setFaultCounts[faultId] = (_setFaultCounts[faultId] ?? 0) + 1;
    _voicePlayer.speak(script.faultKey(faultId));
  }

  void _speakPreviousSetAdviceIfNeeded(
    ExerciseBase exercise,
    GenericExerciseVoiceScript script,
  ) {
    if (_didSpeakPreviousSetAdvice) return;
    if (!exercise.shouldReplayPreviousSetVoiceFaults) return;

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

  Set<String> _faultIdsForRepLog(
    GenericExerciseVoiceScript script,
    RepLog repLog,
  ) {
    final ids = <String>{};

    if (repLog.correctForm) return ids;

    for (final faultType in _faultTypesFromLog(repLog)) {
      ids.addAll(_faultIdsForText(script, faultType));
    }

    return ids;
  }

  RepLog? _latestRepLog(ExerciseBase exercise, int repCount) {
    for (final log in exercise.logger.repLogs.reversed) {
      if (log.repNumber != repCount) continue;
      return log;
    }
    return null;
  }

  RepLog? _latestRepLogAnyNumber(ExerciseBase exercise) {
    if (exercise.logger.repLogs.isEmpty) {
      return null;
    }
    return exercise.logger.repLogs.last;
  }

  Iterable<String> _faultTypesFromLog(RepLog log) sync* {
    final faultTypes = log.data['fault_types'];
    if (faultTypes is Iterable) {
      for (final faultType in faultTypes) {
        final value = faultType.toString().trim();
        if (value.isNotEmpty) yield value;
      }
    }
  }

  Iterable<String> _faultIdsForText(
    GenericExerciseVoiceScript script,
    String text,
  ) sync* {
    final normalizedKey = _normalizeFaultKey(text);
    for (final candidate in _candidateFaultIdsForKey(normalizedKey)) {
      if (script.hasFault(candidate)) yield candidate;
    }

    final normalizedText = _normalizeFaultText(text);
    for (final candidate in _candidateFaultIds(normalizedText)) {
      if (script.hasFault(candidate)) yield candidate;
    }
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
      case 'feet':
        yield 'heel';
        yield 'foot';
        break;
      case 'bent_straight_leg':
        yield 'straight_leg';
        break;
      case 'torso_lean':
        yield 'torso';
        yield 'trunk';
        break;
      case 'back':
        yield 'trunk';
        yield 'torso';
        break;
      case 'core':
        yield 'lumbar';
        yield 'trunk';
        break;
      case 'shallow_depth':
      case 'shallow_lunge':
        yield 'depth_shallow';
        yield 'depth';
        yield 'rear_depth';
        break;
      case 'too_deep':
        yield 'depth_deep';
        break;
      case 'power':
        yield 'takeoff_depth';
        break;
      case 'speed_control':
        yield 'speed';
        yield 'tempo';
        break;
      case 'neck_head':
        yield 'neck';
        yield 'head';
        break;
      case 'knee_angle':
        yield 'knee_angle';
        yield 'knee';
        break;
      case 'hyperextension':
        yield 'lumbar';
        yield 'hip_extension';
        break;
      case 'hip_extension':
        yield 'hip_extension';
        break;
      case 'knee_over_toe':
        yield 'front_knee';
        yield 'knee';
        break;
      case 'inconsistent_step':
        yield 'step_length';
        break;
      case 'not_enough_hold':
        yield 'hold';
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

  bool _isNoCountFeedback(Map<String, String> feedback) {
    final result = _normalizeFaultText(feedback['Result'] ?? '');
    return result.contains('no count') ||
        result.contains('khong tinh') ||
        result.contains('chua tinh');
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

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return _voicePlayer.waitUntilIdle(timeout: timeout);
  }

  @override
  void dispose() {
    _resetHoldProgressTracking();
    _setFaultCounts.clear();
    _voicePlayer.clearQueue();
    _voicePlayer.dispose();
  }
}
