// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:ui' show Size;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose/presence_anomaly_detector.dart';
import '../pose/vika_pose_landmark.dart';
import '../utils/person_detector.dart';

// ---------------------------------------------------------------------------
// Public enums & verdict
// ---------------------------------------------------------------------------

/// Which stage the exercise is in, from the gate's perspective.
/// Defined here (not imported from exercise_base) to avoid a circular import.
enum GatePhase {
  /// notActivated — looking for a confirmed person and a hold-still start.
  seeking,

  /// activated — exercise is running.
  active,

  /// completed — set finished; gate is mostly dormant.
  done,
}

/// Why the gate blocked the frame.
enum GateBlock {
  /// Person not yet confirmed; base shows "looking for person" copy.
  searching,

  /// Exercise is paused (auto or manual); base shows pause copy.
  paused,
}

/// Result of a single [PresenceGate.onPose] or [PresenceGate.onNoPose] call.
///
/// [proceed] false → ExerciseBase must early-return this frame.
/// [personLostNow] → true exactly once when a confirmed person un-confirms
///   in seeking phase; base clears its _holdStillStartedAt on this signal
///   (the only cross-boundary coupling).
/// [personStableMs] → ms the person has been continuously seen while
///   unconfirmed in seeking phase; feeds debugData['personStableMs'].
class GateVerdict {
  const GateVerdict({
    required this.proceed,
    required this.block,
    required this.personLostNow,
    required this.personStableMs,
    this.pausedNow = false,
    this.resumedNow = false,
  });

  final bool proceed;
  final GateBlock? block;
  final bool personLostNow;
  final int personStableMs;
  final bool pausedNow;
  final bool resumedNow;
}

// ---------------------------------------------------------------------------
// PresenceGate
// ---------------------------------------------------------------------------

/// Owns all presence / auto-pause / segmentation-trigger logic.
///
/// ExerciseBase creates one instance and calls [onPose] / [onNoPose] once per
/// frame, before any exercise-specific logic runs. The gate returns a
/// [GateVerdict]; if [GateVerdict.proceed] is false, the base early-returns.
///
/// Clock is injected via the `now` parameter on every frame entry-point so
/// the confirm / grace / resume timers are unit-testable with plain DateTime
/// values (no fake_async needed).
class PresenceGate {
  PresenceGate({PosePresenceSource? detector, bool diagnosticMode = false})
      : _detector = detector ?? PersonDetector(),
        _diagnosticMode = diagnosticMode;

  final PosePresenceSource _detector;
  final bool _diagnosticMode;
  final PresenceAnomalyDetector _anomalyDetector = PresenceAnomalyDetector();

  // Edge-trigger flags: each fires triggerCheck once on the false→true
  // transition, then stays true until reset (avoiding re-fire every frame).
  bool _wasPoseAnomaly = false;
  bool _wasPoseFrameEdgeRisk = false;
  bool _wasPoseLowPresence = false;

  // Whether the last frame was a no-pose frame; cleared the moment pose
  // returns so we can trigger 'pose_returned' before any block path.
  bool _wasNoLandmarks = false;

  // Seeking-phase confirm state.
  bool _personConfirmed = false;
  DateTime? _personSeenSince; // streak start; ??= semantics: only set once

  // Active-phase pause/resume timers.
  DateTime? _personLostSince;
  DateTime? _resumePresenceSince;
  bool _isPaused = false;
  bool _resumeEdgePending = false;

  // True when _isPaused was set by the user tapping pause (not auto-pause).
  // A manual pause is never cleared by presence alone — only manualResume().
  bool _manualPause = false;

  static const Duration _PERSON_CONFIRM_DURATION = Duration(milliseconds: 400);
  // Was 900ms. Cut to 400ms: re-entry now costs ~1s (paused segmentation
  // cadence), so trimming the pause-commit debounce keeps total leave→pause→
  // resume latency in budget. 400ms still spans ~2 trigger samples (200ms
  // cooldown), enough to reject a single dropped frame without false-pausing.
  static const Duration _PERSON_LOST_GRACE = Duration(milliseconds: 400);
  static const Duration _PERSON_RESUME_CONFIRM_DURATION =
      Duration(milliseconds: 320);

  // Average pose-landmark presence below this triggers a segmentation check.
  static const double _AVG_LOW_PRESENCE_THRESHOLD = 0.35;

  // Frame-edge risk (pose_frame_edge trigger): a person is likely partially
  // cropped when enough visible joints sit at or over the frame boundary.
  static const double _FRAME_EDGE_MARGIN_RATIO =
      0.04; // "near edge" band per axis
  static const int _FRAME_EDGE_MIN_VISIBLE =
      8; // need this many visible joints to judge
  static const int _FRAME_EDGE_OUTSIDE_COUNT =
      2; // >= this many fully outside => risk
  static const int _FRAME_EDGE_NEAR_EDGE_COUNT =
      5; // >= this many within margin => risk

  // ---------------------------------------------------------------------------
  // Read-only surface for ExerciseBase getters
  // ---------------------------------------------------------------------------

  bool get isPaused => _isPaused;
  bool get personConfirmed => _personConfirmed;
  bool get personDetected => _detector.personDetected;
  double get presenceScore => _detector.presenceScore;

  // ---------------------------------------------------------------------------
  // Per-frame entry points
  // ---------------------------------------------------------------------------

  /// Called by ExerciseBase when pose landmarks are present in the current frame.
  ///
  /// Invariant: steps must run in this exact order to preserve the original
  /// ExerciseBase pipeline behaviour.
  GateVerdict onPose({
    required DateTime now,
    required GatePhase phase,
    required Map<PoseLandmarkType, PoseLandmark> landmarks,
    Size? imageSize,
  }) {
    // Step 1: pose-returned trigger fires BEFORE any block/return.
    // When landmarks come back after a no-landmark run, immediately ask
    // segmentation for a fresh sample before the not-confirmed early-return
    // can block this path.
    if (_wasNoLandmarks) {
      unawaited(_detector.triggerCheck(reason: 'pose_returned'));
      _wasNoLandmarks = false;
    }

    // Step 2: Sync presence state. Capture the was→now confirmed transition
    // to produce personLostNow without ExerciseBase needing a back-reference.
    final wasConfirmed = _personConfirmed;
    final wasPaused = _isPaused;
    _syncPresence(now: now, phase: phase);
    // personLostNow is seeking-only; active/done never clear _holdStillStartedAt.
    final personLostNow =
        phase == GatePhase.seeking && wasConfirmed && !_personConfirmed;

    // Step 3: Block decisions.
    final pausedNow = _consumePauseEdge(wasPaused: wasPaused);
    final resumedNow = _consumeResumeEdge();
    if (phase == GatePhase.seeking && !_personConfirmed) {
      final stableMs = _personSeenSince == null
          ? 0
          : now.difference(_personSeenSince!).inMilliseconds;
      return GateVerdict(
        proceed: false,
        block: GateBlock.searching,
        personLostNow: personLostNow,
        personStableMs: stableMs,
        pausedNow: pausedNow,
        resumedNow: resumedNow,
      );
    }
    if (phase == GatePhase.active && _isPaused) {
      // No per-frame poke here anymore. Re-confirmation runs off the periodic
      // paused cadence (1s, set on the auto-pause edge) instead of hammering
      // triggerCheck every frame at the 200ms cooldown (5 samples/s). _syncPresence
      // above already advanced the resume timer from that polled personDetected.
      return GateVerdict(
        proceed: false,
        block: GateBlock.paused,
        personLostNow: false,
        personStableMs: 0,
        pausedNow: pausedNow,
        resumedNow: resumedNow,
      );
    }

    // Step 4: Trouble triggers — run on every NON-BLOCKED frame (seeking-
    // confirmed, active-unpaused, done). Blocked frames intentionally skip
    // this section so the anomaly detector's window doesn't drift during a
    // pause and fire phantom triggers on resume.
    final avgPresence = _computeAvgPresence(landmarks);

    // Low-presence and edge-risk triggers: active phase only.
    final poseLowPresence = avgPresence < _AVG_LOW_PRESENCE_THRESHOLD;
    if (phase == GatePhase.active && poseLowPresence && !_wasPoseLowPresence) {
      unawaited(_detector.triggerCheck(reason: 'pose_low_presence'));
    }
    _wasPoseLowPresence = poseLowPresence;

    final poseFrameEdgeRisk =
        _isPoseFrameEdgeRisk(landmarks, imageSize: imageSize);
    if (phase == GatePhase.active &&
        poseFrameEdgeRisk &&
        !_wasPoseFrameEdgeRisk) {
      unawaited(_detector.triggerCheck(reason: 'pose_frame_edge'));
    }
    _wasPoseFrameEdgeRisk = poseFrameEdgeRisk;

    // Anomaly trigger: any non-blocked phase (seeking-confirmed, active, done).
    _anomalyDetector.update(avgPresence);
    final nowAnomaly = _anomalyDetector.isAnomalyConfirmed;
    if (nowAnomaly && !_wasPoseAnomaly) {
      unawaited(_detector.triggerCheck(reason: 'pose_anomaly'));
    }
    _wasPoseAnomaly = nowAnomaly;

    return GateVerdict(
      proceed: true,
      block: null,
      personLostNow:
          personLostNow, // always false when proceed=true (see above)
      personStableMs: 0,
      pausedNow: pausedNow,
      resumedNow: resumedNow,
    );
  }

  /// Called by ExerciseBase when no pose landmarks are detected in the frame.
  ///
  /// Returns a verdict whose [GateVerdict.personLostNow] the base uses to
  /// clear _holdStillStartedAt. [GateVerdict.proceed] is always true — the
  /// base always builds feedback strings for no-pose frames.
  GateVerdict onNoPose({required DateTime now, required GatePhase phase}) {
    // Reason differs: first no-pose frame vs. sustained no-pose with stale
    // personDetected. Only trigger when there's actually something to re-check.
    final hadLandmarksLastFrame = !_wasNoLandmarks;
    if (hadLandmarksLastFrame || _detector.personDetected) {
      unawaited(_detector.triggerCheck(
        reason: hadLandmarksLastFrame
            ? 'no_landmarks'
            : 'no_landmarks_stale_present',
      ));
    }

    _wasNoLandmarks = true;
    // Reset trouble flags; if pose returns and is anomalous it'll re-trigger.
    _wasPoseAnomaly = false;
    _wasPoseLowPresence = false;
    _wasPoseFrameEdgeRisk = false;

    final wasConfirmed = _personConfirmed;
    final wasPaused = _isPaused;
    _syncPresence(now: now, phase: phase);
    final personLostNow =
        phase == GatePhase.seeking && wasConfirmed && !_personConfirmed;
    final pausedNow = _consumePauseEdge(wasPaused: wasPaused);
    final resumedNow = _consumeResumeEdge();

    return GateVerdict(
      proceed: true,
      block: null,
      personLostNow: personLostNow,
      personStableMs: 0,
      pausedNow: pausedNow,
      resumedNow: resumedNow,
    );
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Call when the exercise transitions from notActivated → activated.
  /// Resets trouble detectors and switches segmentation to the low-cadence
  /// activated interval (saves battery; one-shot triggers handle anomalies).
  void onActivated() {
    _resetTroubleDetectors();
    unawaited(_detector.useActivatedCadence());
  }

  /// Called when the user taps the pause button. Sets both pause flags so
  /// presence alone can never clear this pause — only [manualResume] can.
  void manualPause() {
    _isPaused = true;
    _manualPause = true;
    // Presence can't clear a manual pause, so there's nothing to sample fast
    // for: sit on the cheap 8s baseline (also undoes a 1s paused cadence if the
    // user manual-paused on top of an existing auto-pause).
    unawaited(_detector.useActivatedCadence());
  }

  /// Called when the user taps resume. Seeds the resume-presence timer with
  /// `now` (the UI-clock value, not a frame timestamp) so the 320ms gate
  /// begins from the moment the user tapped, not the next frame.
  void manualResume(DateTime now) {
    _isPaused = false;
    _manualPause = false;
    _resumeEdgePending = true;
    _resumePresenceSince = now;
    _personLostSince = null;
    _resetTroubleDetectors();
    // Back to the 8s activated baseline (restores it if a prior auto-pause had
    // dropped us to the 1s paused cadence), then one fresh sample to re-confirm.
    unawaited(_detector.useActivatedCadence());
    unawaited(_detector.triggerCheck(reason: 'manual_resume'));
  }

  Future<void> runDetection([InputImage? input]) => _detector.detect(input);

  Future<void> close() => _detector.close();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Mirrors the original _syncPresenceState, driven purely by
  /// _detector.personDetected (hasPose is intentionally ignored — keeping
  /// the same invariant as the original code).
  void _syncPresence({required DateTime now, required GatePhase phase}) {
    final presentNow = _detector.personDetected;

    if (phase == GatePhase.seeking) {
      if (!_personConfirmed) {
        if (presentNow) {
          _personSeenSince ??= now; // record start of streak
          if (now.difference(_personSeenSince!) >= _PERSON_CONFIRM_DURATION) {
            _personConfirmed = true;
          }
        } else {
          _personSeenSince = null; // streak broken; reset
        }
      } else if (!presentNow) {
        // Person was confirmed but just left. Signal propagated via personLostNow
        // on the verdict; base clears _holdStillStartedAt.
        _personConfirmed = false;
        _personSeenSince = null;
      }
      return;
    }

    // done phase → no-op (same as original: exerciseState != activated returns).
    if (phase != GatePhase.active) return;

    if (presentNow) {
      _personLostSince = null;
      // A manual pause is only cleared by manualResume, not by presence.
      if (_isPaused && !_manualPause) {
        _resumePresenceSince ??= now;
        if (now.difference(_resumePresenceSince!) >=
            _PERSON_RESUME_CONFIRM_DURATION) {
          _isPaused = false;
          _resumeEdgePending = true;
          _resetTroubleDetectors();
          // Auto-resume edge: back to the cheap 8s activated baseline (one-shot
          // triggers handle anomalies from here). Undoes the 1s paused cadence.
          unawaited(_detector.useActivatedCadence());
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
        !_diagnosticMode) {
      _isPaused = true;
      _resetTroubleDetectors();
      // Auto-pause edge: speed the segmentation poll from the 8s activated
      // baseline to 1s so we notice the person return within ~1.3s, without the
      // per-frame triggerCheck poke this replaces. Only auto-pause reaches here
      // (the !_isPaused guard means a manual pause never re-enters this branch).
      unawaited(_detector.usePausedCadence());
    }
  }

  bool _consumePauseEdge({required bool wasPaused}) {
    return !wasPaused && _isPaused && !_manualPause;
  }

  bool _consumeResumeEdge() {
    final edge = _resumeEdgePending;
    _resumeEdgePending = false;
    return edge;
  }

  /// Resets anomaly detector and edge-trigger flags.
  /// Called on: activation, auto-resume, manual resume, and when _isPaused is set.
  void _resetTroubleDetectors() {
    _anomalyDetector.reset();
    _wasPoseAnomaly = false;
    _wasPoseLowPresence = false;
    _wasPoseFrameEdgeRisk = false;
    _wasNoLandmarks = false;
  }

  double _computeAvgPresence(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (landmarks.isEmpty) return 0.0;
    double total = 0.0;
    for (final lm in landmarks.values) {
      total += lm.presence;
    }
    return total / landmarks.length;
  }

  /// True when enough visible landmarks are at or outside the frame edge,
  /// suggesting the person is partially cropped. Mirrors the original
  /// _isPoseFrameEdgeRisk in ExerciseBase exactly.
  ///
  /// Thresholds: ≥2 fully outside or ≥5 within the 4% margin.
  bool _isPoseFrameEdgeRisk(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    required Size? imageSize,
  }) {
    if (imageSize == null || imageSize == Size.zero) return false;
    if (imageSize.width <= 0 || imageSize.height <= 0) return false;

    final marginX = imageSize.width * _FRAME_EDGE_MARGIN_RATIO;
    final marginY = imageSize.height * _FRAME_EDGE_MARGIN_RATIO;
    var visibleCount = 0;
    var edgeCount = 0;
    var outsideCount = 0;

    for (final landmark in landmarks.values) {
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

    if (visibleCount < _FRAME_EDGE_MIN_VISIBLE) return false;
    return outsideCount >= _FRAME_EDGE_OUTSIDE_COUNT ||
        edgeCount >= _FRAME_EDGE_NEAR_EDGE_COUNT;
  }
}
