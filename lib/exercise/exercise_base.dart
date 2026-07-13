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
import '../services/viettel_tts_service.dart';
import '../voice/policy_voice_coach.dart';
import '../voice/voice_coach.dart';
import '../voice/voice_content.dart';
import '../voice/voice_sink.dart';
import 'dart:math' as math;
import 'fault_record.dart';
export 'hold/hold_phase.dart';
import 'hold/hold_phase.dart';
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

enum GuidanceClass {
  phoneLandscape,
  phonePortrait,
  turnSide,
  faceCamera,
  bodyInFrame,
  lighting,
  searching,
  paused,
  resume,
  setupPosition,
  holdStill,
}

class GuidanceSignal {
  const GuidanceSignal(
    this.kind, {
    this.title,
    this.body,
  });

  const GuidanceSignal.phoneLandscape()
      : this(
          GuidanceClass.phoneLandscape,
          title: 'Xoay ngang máy',
          body: 'Bài này cần điện thoại nằm ngang để AI thấy rõ toàn thân bạn.',
        );

  const GuidanceSignal.phonePortrait()
      : this(
          GuidanceClass.phonePortrait,
          title: 'Xoay dọc máy',
          body: 'Bài này cần màn hình dọc để AI theo dõi ổn định hơn.',
        );

  const GuidanceSignal.turnSide({String? title, String? body})
      : this(
          GuidanceClass.turnSide,
          title: title,
          body: body,
        );

  const GuidanceSignal.faceCamera({String? title, String? body})
      : this(
          GuidanceClass.faceCamera,
          title: title,
          body: body,
        );

  const GuidanceSignal.bodyInFrame({String? title, String? body})
      : this(
          GuidanceClass.bodyInFrame,
          title: title,
          body: body,
        );

  const GuidanceSignal.lighting({String? title, String? body})
      : this(
          GuidanceClass.lighting,
          title: title,
          body: body,
        );

  const GuidanceSignal.searching()
      : this(
          GuidanceClass.searching,
          title: 'Đang tìm người',
          body: 'Đứng trong khung hình để bắt đầu.',
        );

  const GuidanceSignal.paused()
      : this(
          GuidanceClass.paused,
          title: 'Tạm dừng',
          body: 'Quay lại khung hình để tiếp tục nhé.',
        );

  const GuidanceSignal.resume()
      : this(
          GuidanceClass.resume,
          title: 'Oke',
          body: 'Tiếp tục nhé.',
        );

  const GuidanceSignal.setupPosition({String? title, String? body})
      : this(
          GuidanceClass.setupPosition,
          title: title,
          body: body,
        );

  const GuidanceSignal.holdStill({String? title, String? body})
      : this(
          GuidanceClass.holdStill,
          title: title,
          body: body,
        );

  final GuidanceClass kind;
  final String? title;
  final String? body;

  String get feedbackMessage {
    final copy = body ?? title;
    if (copy != null && copy.isNotEmpty) return copy;
    return switch (kind) {
      GuidanceClass.phoneLandscape => 'Xoay ngang máy.',
      GuidanceClass.phonePortrait => 'Xoay dọc máy.',
      GuidanceClass.turnSide => 'Quay nghiêng người với camera.',
      GuidanceClass.faceCamera => 'Quay mặt về camera.',
      GuidanceClass.bodyInFrame => 'Giữ cơ thể trong khung hình.',
      GuidanceClass.lighting => 'Đứng chỗ sáng hơn để AI nhận diện rõ hơn.',
      GuidanceClass.searching =>
        'Đang tìm người... Vui lòng đứng trong khung hình.',
      GuidanceClass.paused => 'Tạm dừng - quay lại khung hình để tiếp tục.',
      GuidanceClass.resume => 'Oke, tiếp tục nhé.',
      GuidanceClass.setupPosition => 'Vào tư thế và giữ yên để bắt đầu.',
      GuidanceClass.holdStill => 'Giữ yên để bắt đầu.',
    };
  }
}

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
  Map<String, String> phaseStatus = {};

  void setPhaseStatus(String phase, String message) {
    phaseStatus[phase] = message;
  }

  void clear() {
    feedback.clear();
    phaseStatus.clear();
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
  bool _reactivatingAfterPause = false;

  /// Launch-flow context for the structural completion cue. A direct launch is
  /// a single final set; the multi-set screen stamps earlier fresh sets false.
  bool isFinalSet = true;

  /// The per-set target(s) this exercise was launched with, injected at
  /// construction by the launch screen's resolved volume (prescription >
  /// catalog > floor — see `_ExerciseExperienceSpec._resolveVolume`). Kept on
  /// the base so any consumer can read them polymorphically WITHOUT downcasting
  /// to a concrete subclass; the voice coach uses [targetReps] to know when a
  /// set is nearly done (final-rep awareness).
  ///
  /// Both are independent and optional so the base covers every modality:
  ///   reps only  -> targetReps set,    targetSeconds null
  ///   hold only  -> targetReps null,   targetSeconds set
  ///   mixed      -> both set (e.g. N reps each held M seconds)
  /// A subclass forwards whatever target(s) it takes via `super(...)`. Left
  /// null for exercises not yet migrated — a null target simply means "unknown".
  final int? targetReps;
  final int? targetSeconds;

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

  /// Feel-tune window that suppresses in-position-fixable guidance VOICE while
  /// the user settles (fallback width when no intro audio played; otherwise the
  /// adapter pins/closes the window around the intro's actual duration). The
  /// UI is never grace-gated — signage renders live from frame one. Phone
  /// orientation, searching, pause/resume, and setup states are intentionally
  /// outside this set and speak from frame one too.
  static const int kGuidanceSignalGraceMs = 3500;
  static const Set<GuidanceClass> kGuidanceSignalGraceClasses = <GuidanceClass>{
    GuidanceClass.bodyInFrame,
    GuidanceClass.lighting,
    GuidanceClass.turnSide,
    GuidanceClass.faceCamera,
  };

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
  GuidanceSignal? guidanceSignal;
  int? _guidanceGraceStartedAtMs;

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

  // Presence / auto-pause / segmentation-trigger gate. Injectable for tests
  // only (same pattern as PresenceGate's own injectable detector) — the
  // resume-re-hold regression suite needs to drive processPose without the
  // real PersonDetector/ML Kit plumbing.
  final PresenceGate _gate;

  bool get isPaused => _gate.isPaused;
  bool get isReactivatingAfterPause => _reactivatingAfterPause;

  /// Manually pause the exercise (e.g. user tapped pause button).
  /// Allowed in any state — pausing pre-activation is odd but harmless, and
  /// the pause overlay always exposes a resume button so nobody gets stuck.
  void manualPause() {
    _gate.manualPause();
  }

  /// Manually resume after a manual pause.
  void manualResume() {
    _gate.manualResume(DateTime.now());
    _beginPauseReactivationIfNeeded();
  }

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

  /// Elapsed milliseconds of the in-progress activation hold, or null when no
  /// hold is underway (not in `notActivated`, or the user is not yet holding a
  /// valid start position). Read-only window the voice coach needs to sync the
  /// voiced activation countdown to the 3s hold — it does not gate on
  /// `personConfirmed` the way [activationProgress] does, because the countdown
  /// keys off the same `_holdStillStartedAt` clock the state machine activates
  /// on, not the UI's presence-confirmed progress ring.
  int? get holdStillElapsedMs {
    if (exerciseState != ExerciseState.notActivated) return null;
    final startedAt = _holdStillStartedAt;
    if (startedAt == null) return null;
    return frameTimestamp.difference(startedAt).inMilliseconds;
  }

  /// True while a rep-counted hold is re-earning its start position between
  /// holds. The base activation state stays `activated`; exercises opt in so
  /// the shared countdown and gauge can follow their re-arm clock without
  /// replaying any set-start lifecycle behavior.
  bool get isReArmingHold => false;

  ExerciseBase({this.targetReps, this.targetSeconds, PresenceGate? gate})
      : _gate = gate ?? PresenceGate(diagnosticMode: kDiagnosticMode) {
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

  /// Turns a gate block reason into typed guidance. All copy lives here in the
  /// base, never in the gate — the gate is UI-language-free and returns enums
  /// only, so wording changes touch exactly one place.
  GuidanceSignal _guidanceSignalForBlock(GateBlock block) {
    switch (block) {
      case GateBlock.searching:
        return const GuidanceSignal.searching();
      case GateBlock.paused:
        return const GuidanceSignal.paused();
    }
  }

  void publishGuidanceSignal(
    GuidanceSignal signal, {
    bool publishFeedback = true,
  }) {
    guidanceSignal = signal;
    if (publishFeedback) {
      resultIssues.feedback['System'] = signal.feedbackMessage;
    }
  }

  void clearGuidanceSignal({bool clearFeedback = false}) {
    guidanceSignal = null;
    if (clearFeedback) {
      resultIssues.feedback.remove('System');
    }
  }

  void beginGuidanceSignalGrace({required int nowMs}) {
    _guidanceGraceStartedAtMs = nowMs;
    // Live seam: the voice adapter pins this window to `now` each frame while
    // the setup-intro audio plays, then CLOSES it at intro-audio-end via
    // [endGuidanceSignalGrace] — the window's width is the intro's duration.
  }

  /// Closes the voice-grace window immediately (intro-audio-end: no settle
  /// tail; the safety latch's ~1s enter debounce is the only residual delay).
  /// Backdates the anchor rather than nulling it — a null anchor would be
  /// re-seeded by [_ensureGuidanceSignalGraceStarted] next frame, silently
  /// restarting a fresh window.
  void endGuidanceSignalGrace({required int nowMs}) {
    _guidanceGraceStartedAtMs = nowMs - kGuidanceSignalGraceMs;
  }

  void _ensureGuidanceSignalGraceStarted() {
    _guidanceGraceStartedAtMs ??= frameTimestampMs;
  }

  bool isGuidanceGraceActive(GuidanceClass kind) {
    if (!kGuidanceSignalGraceClasses.contains(kind)) return false;
    final startedAt = _guidanceGraceStartedAtMs;
    if (startedAt == null) return false;
    return frameTimestampMs - startedAt < kGuidanceSignalGraceMs;
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
    _ensureGuidanceSignalGraceStarted();

    resultIssues.feedback.clear();
    clearGuidanceSignal();

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
    final reactivationAlreadyPending = _reactivatingAfterPause;
    // Re-hold is demanded ONLY on the gate's one-frame resume edge (manual or
    // auto — both set it). Calling this unconditionally demoted EVERY
    // activated frame back to notActivated: activate → demote → re-hold →
    // 3-2-1 → activate → demote… the infinite countdown loop Nam hit on
    // device (07-11).
    final startedReactivation =
        verdict.resumedNow ? _beginPauseReactivationIfNeeded() : false;
    if (verdict.resumedNow &&
        !startedReactivation &&
        !reactivationAlreadyPending) {
      publishGuidanceSignal(
        const GuidanceSignal.resume(),
        publishFeedback: false,
      );
    }
    // proceed=false → gate blocked this frame (searching or paused). Base owns
    // the Vietnamese copy; the gate only names the reason via an enum.
    if (!verdict.proceed) {
      publishGuidanceSignal(_guidanceSignalForBlock(verdict.block!));
      return [repCount, resultIssues.feedback];
    }

    // Auto-detect orientation
    cameraFacing = detectCameraFacing(smoothedLandmarks);

    // Safety check (subclass logic)
    final safetySignal = checkSafety(smoothedLandmarks);
    if (safetySignal != null) {
      publishGuidanceSignal(safetySignal);
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
    _ensureGuidanceSignalGraceStarted();
    resultIssues.feedback.clear();
    clearGuidanceSignal();

    final verdict = _gate.onNoPose(now: frameTimestamp, phase: _gatePhase);
    if (verdict.personLostNow) _holdStillStartedAt = null;
    // The gate's resume edge is one-frame and CONSUMED by whichever verdict
    // reads it. A resume landing on a no-pose frame (user taps resume, then
    // walks into frame) must still demand the re-hold, or the edge is eaten
    // and the set continues without one. No resume line here: the
    // seeking-guidance below (searching/body-in-frame) is the audible
    // feedback in this state, and the re-hold countdown follows.
    if (verdict.resumedNow) _beginPauseReactivationIfNeeded();

    if (exerciseState == ExerciseState.completed) {
      return {'Result': 'Hoàn thành! $repCount reps'};
    }

    if (exerciseState == ExerciseState.notActivated) {
      publishGuidanceSignal(
        _gate.personConfirmed
            ? const GuidanceSignal.bodyInFrame(
                title: 'Chỉnh khung hình',
                body: 'Giữ toàn thân trong khung hình để bắt đầu.',
              )
            : const GuidanceSignal.searching(),
      );
    } else if (_gate.isPaused || !_gate.personDetected) {
      publishGuidanceSignal(const GuidanceSignal.paused());
    } else {
      publishGuidanceSignal(
        const GuidanceSignal.bodyInFrame(
          title: 'Chỉnh khung hình',
          body: 'Giữ toàn thân trong khung hình để AI theo dõi ổn định hơn.',
        ),
      );
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

  ExerciseVoiceCoach? createVoiceCoach() {
    // Keep the same per-exercise footprint the legacy generic coach used:
    // both script types map fault ids to '<slug>.<id>' asset keys.
    final legacy =
        GenericExerciseVoiceAssets.scriptForExerciseName(exerciseName);
    final isRepCountedHold = usesRepCountedHolds;
    final bundle = isRepCountedHold
        ? VoiceDefaults.repCountedHold
        : liveHoldTargetSeconds != null
            ? VoiceDefaults.timeBased
            : VoiceDefaults.repBased;
    final script = VoiceScript.from(
      bundle,
      slug: legacy.slug,
      faultIds: legacy.faultIds,
      reminderPools: isRepCountedHold
          ? <String, List<String>>{
              for (final id in legacy.faultIds)
                id: <String>['${legacy.slug}.${id}_reminder'],
            }
          : const <String, List<String>>{},
      hustleFinalPool: isRepCountedHold
          ? VoiceLib.hustleRepCountedHoldFinal
          : const <String>[],
      repStartPhaseKeys: isRepCountedHold
          ? <String>{REP_COUNTED_HOLD_PHASE_HOLDING}
          : const <String>{},
    );
    return PolicyVoiceCoach(
      script: script,
      coach: VoiceCoach(sink: AssetVoiceSink()),
      targetReps: targetReps,
      countsByRepNumber: liveHoldTargetSeconds == null || isRepCountedHold,
    );
  }

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
    if (!isLandmarkConfident(ls) ||
        !isLandmarkConfident(rs) ||
        !isLandmarkConfident(lh) ||
        !isLandmarkConfident(rh)) {
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

  bool _beginPauseReactivationIfNeeded() {
    if (exerciseState != ExerciseState.activated) return false;
    exerciseState = ExerciseState.notActivated;
    _holdStillStartedAt = null;
    _reactivatingAfterPause = true;
    onPauseReactivationStarted();
    return true;
  }

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
            final reactivatedAfterPause = _reactivatingAfterPause;
            exerciseState = ExerciseState.activated;
            _holdStillStartedAt = null;
            _reactivatingAfterPause = false;
            _gate.onActivated();
            beginGuidanceSignalGrace(nowMs: frameTimestampMs);
            if (reactivatedAfterPause) {
              onExerciseReactivatedAfterPause();
            } else {
              onExerciseActivated();
            }
          } else {
            publishGuidanceSignal(
              GuidanceSignal.holdStill(
                title: 'Giữ yên',
                body:
                    'Giữ yên... ${remaining.clamp(0.0, 99.0).toStringAsFixed(0)}s',
              ),
            );
          }
        } else {
          _holdStillStartedAt = null;
          publishGuidanceSignal(
            const GuidanceSignal.setupPosition(
              title: 'Vào vị trí',
              body: 'Vào tư thế và giữ yên để bắt đầu.',
            ),
          );
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

  /// Resume re-hold entered `notActivated`: subclasses can reset transient
  /// in-progress phase state, but must preserve completed reps and logs.
  void onPauseReactivationStarted() {}

  /// The resume re-hold completed. Keep set progress intact; this is not a new
  /// set activation and must not call subclasses' initial set reset path.
  void onExerciseReactivatedAfterPause() {
    if (!_sessionStopwatch.isRunning) {
      _sessionStopwatch.start();
    }
  }

  bool requestStop();

  GuidanceSignal? checkSafety(
      Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks);

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

  /// Remaining seconds in an in-set rest, or null outside the timed rest.
  double? get liveRestSeconds => null;

  /// Optional target used by the shared in-set rest ring.
  double? get liveRestTargetSeconds => null;

  /// True only when one completed hold is one rep. Most exercises that expose
  /// a live hold timer are still ordinary rep/timer exercises and must keep
  /// their existing voice behavior.
  bool get usesRepCountedHolds => false;

  /// Faults known so far in the rep-in-progress, exposed the instant a
  /// metric detects them. Exercises that do not opt in keep the post-rep
  /// RepLog voice path.
  List<FaultRecord> get liveFaults => const [];
}
