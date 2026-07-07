/* =========================================================================
    PersonDetector — "Is there a real person in frame?"

    Uses native ML Kit Selfie Segmentation aggregate events. Native code counts
    mask pixels and sends ratios only; Dart keeps smoothing, presence blending,
    and hysteresis so behavior stays aligned with the previous Flutter wrapper.
    ========================================================================= */

import 'dart:async';
import 'dart:math' as math;

import 'segmentation_channel.dart';

/// Minimal interface for the person-presence signal. Extracted so PresenceGate
/// can accept a fake in tests without touching platform channels.
abstract interface class PosePresenceSource {
  bool get personDetected;
  double get presenceScore;
  Future<bool> detect([Object? _]);
  Future<void> triggerCheck({String reason = 'unknown'});
  Future<void> useActivatedCadence();
  Future<void> usePausedCadence();
  Future<void> close();
}

class PersonDetectorConfig {
  /// Minimum percentage of frame pixels that must be "person" (0.0–1.0)
  static const double MIN_PERSON_RATIO = 0.03;

  /// Lower threshold to leave the detected state.
  /// Creates hysteresis so the state does not flicker frame-to-frame.
  static const double MIN_PERSON_RATIO_EXIT = 0.02;

  /// Per-pixel confidence threshold to count as "person"
  static const double PIXEL_CONFIDENCE_THRESHOLD = 0.82;

  /// A softer threshold used to estimate body coverage when the mask is noisy.
  static const double SOFT_PIXEL_CONFIDENCE_THRESHOLD = 0.35;

  /// Responsive cadence while the app is looking for / confirming the person.
  static const Duration SEARCH_PROCESS_INTERVAL = Duration(milliseconds: 2000);

  /// Low baseline cadence after exercise activation. Pose-presence drops can
  /// still request a one-shot sample through [triggerCheck].
  static const Duration ACTIVATED_PROCESS_INTERVAL =
      Duration(milliseconds: 8000);

  /// Cadence while auto-paused (person walked away mid-set). A periodic 1s poll
  /// re-confirms their return ~5x cheaper than the old per-frame triggerCheck
  /// poke — which hit the 200ms cooldown = 5 samples/s — while still resuming in
  /// ~1.3s (≤1s to next poll + PERSON_RESUME_CONFIRM 320ms). A *manual* pause
  /// stays on the slow ACTIVATED baseline instead: presence can never clear a
  /// manual pause, so there is nothing to sample for.
  static const Duration PAUSED_PROCESS_INTERVAL = Duration(milliseconds: 1000);

  /// Coalesce simultaneous one-shot sample requests from multiple triggers.
  static const Duration REQUEST_SAMPLE_COOLDOWN = Duration(milliseconds: 200);

  /// EMA smoothing for person coverage.
  static const double RATIO_SMOOTHING_ALPHA = 0.30;

  /// Soft mask fallback weight. Soft pixels help, but weak confidence alone
  /// should not count as the same evidence as high-confidence person pixels.
  static const double SOFT_RATIO_SCORE_WEIGHT = 0.45;
}

class PersonDetector implements PosePresenceSource {
  final SegmentationChannel _channel;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _isStarted = false;
  bool _isClosed = false;
  Duration? _configuredMinProcessInterval;

  /// Last computed person ratio (0.0–1.0) for debug display
  double lastPersonRatio = 0.0;

  /// Last soft person ratio (0.0–1.0) for debug display.
  double lastSoftPersonRatio = 0.0;

  /// Smoothed ratio used by UI/business logic.
  double smoothedPersonRatio = 0.0;

  /// Smoothed soft ratio used as a fallback when high-confidence mask is sparse.
  double smoothedSoftPersonRatio = 0.0;

  /// Blend of high-confidence body coverage and softer body coverage.
  @override
  double presenceScore = 0.0;

  /// Whether a person was detected in the last processed frame
  @override
  bool personDetected = false;
  DateTime? _lastSegmentationEventAt;
  bool _smoothedInitialized = false;

  int? get configuredMinProcessIntervalMs =>
      _configuredMinProcessInterval?.inMilliseconds;

  int? get lastSegmentationEventAgeMs {
    final last = _lastSegmentationEventAt;
    if (last == null) return null;
    return DateTime.now().difference(last).inMilliseconds;
  }

  PersonDetector({SegmentationChannel? channel})
      : _channel = channel ?? SegmentationChannel() {
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_isClosed || _isStarted) return;
    _isStarted = true;

    try {
      _subscription = _channel.eventStream.listen(
        _handleSegmentationEvent,
        onError: (_) {
          // If segmentation fails, do not hard-block the workout.
        },
      );

      await _configureMinProcessInterval(
        PersonDetectorConfig.SEARCH_PROCESS_INTERVAL,
      );
      if (_isClosed) {
        await _disposeChannelQuietly();
        return;
      }
      await _channel.start();
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
    }
  }

  /// Returns the cached native segmentation state.
  /// The optional argument keeps existing call sites source-compatible.
  @override
  Future<bool> detect([Object? _]) async {
    if (!_isStarted && !_isClosed) {
      await _initialize();
    }
    return personDetected;
  }

  Future<void> useSearchCadence() async {
    if (!_isStarted && !_isClosed) {
      await _initialize();
    }
    await _configureMinProcessInterval(
      PersonDetectorConfig.SEARCH_PROCESS_INTERVAL,
    );
  }

  @override
  Future<void> useActivatedCadence() async {
    if (!_isStarted && !_isClosed) {
      await _initialize();
    }
    await _configureMinProcessInterval(
      PersonDetectorConfig.ACTIVATED_PROCESS_INTERVAL,
    );
  }

  @override
  Future<void> usePausedCadence() async {
    if (!_isStarted && !_isClosed) {
      await _initialize();
    }
    await _configureMinProcessInterval(
      PersonDetectorConfig.PAUSED_PROCESS_INTERVAL,
    );
  }

  Future<void> _configureMinProcessInterval(Duration interval) async {
    if (_isClosed || _configuredMinProcessInterval == interval) return;

    try {
      await _channel.initialize(
        pixelConfidenceThreshold:
            PersonDetectorConfig.PIXEL_CONFIDENCE_THRESHOLD,
        softPixelConfidenceThreshold:
            PersonDetectorConfig.SOFT_PIXEL_CONFIDENCE_THRESHOLD,
        minProcessIntervalMs: interval.inMilliseconds,
      );
      _configuredMinProcessInterval = interval;
    } catch (_) {
      // Native segmentation is an optional signal; pose logic can continue.
    }
  }

  /// Counters for trigger frequency, keyed by reason.
  final Map<String, int> _triggerCountByReason = <String, int>{};
  DateTime? _lastTriggerAt;

  /// Trigger frequency map for debug overlay.
  Map<String, int> get triggerCountByReason =>
      Map<String, int>.unmodifiable(_triggerCountByReason);

  /// Force a fresh segmentation sample. Bypasses the native process interval
  /// once on the native side. Caller provides a reason for diagnostics.
  ///
  /// Self-rate-limited at 200ms to prevent thrashing if multiple triggers
  /// fire simultaneously.
  @override
  Future<void> triggerCheck({String reason = 'unknown'}) async {
    if (_isClosed || !_isStarted) return;

    final now = DateTime.now();
    final last = _lastTriggerAt;
    if (last != null &&
        now.difference(last) < PersonDetectorConfig.REQUEST_SAMPLE_COOLDOWN) {
      return;
    }
    _lastTriggerAt = now;

    _triggerCountByReason[reason] = (_triggerCountByReason[reason] ?? 0) + 1;

    try {
      await _channel.requestSample();
    } catch (_) {
      // Trigger is best-effort. Native may be temporarily unavailable.
    }
  }

  /// Fired once per native segmentation sample. Turns two raw mask ratios into
  /// a smoothed [presenceScore] and a debounced [personDetected] boolean.
  ///
  /// Two kinds of ratio arrive from native:
  /// - personRatio: fraction of frame pixels that are person at HIGH confidence.
  /// - softPersonRatio: same, but at a LOWER confidence threshold — catches a
  ///   noisy/backlit body the strict mask misses, so it's kept as a fallback.
  void _handleSegmentationEvent(Map<String, dynamic> event) {
    final personRatio = (event['personRatio'] as num?)?.toDouble();
    final softRatio = (event['softPersonRatio'] as num?)?.toDouble();
    if (personRatio == null || softRatio == null) {
      return;
    }

    lastPersonRatio = personRatio;
    lastSoftPersonRatio = softRatio;
    _lastSegmentationEventAt = DateTime.now();

    // Instantaneous (un-smoothed) evidence for THIS frame. Soft ratio is
    // discounted by SOFT_RATIO_SCORE_WEIGHT (0.45) so weak-confidence pixels
    // never count as strongly as high-confidence ones.
    final currentScore = math.max(
      lastPersonRatio,
      lastSoftPersonRatio * PersonDetectorConfig.SOFT_RATIO_SCORE_WEIGHT,
    );

    // EMA smoothing (alpha 0.30) damps single-frame mask noise. First sample has
    // no history, so seed the smoothed values with the raw ones.
    if (!_smoothedInitialized) {
      smoothedPersonRatio = lastPersonRatio;
      smoothedSoftPersonRatio = lastSoftPersonRatio;
      _smoothedInitialized = true;
    } else {
      smoothedPersonRatio = (smoothedPersonRatio *
              (1.0 - PersonDetectorConfig.RATIO_SMOOTHING_ALPHA)) +
          (lastPersonRatio * PersonDetectorConfig.RATIO_SMOOTHING_ALPHA);

      smoothedSoftPersonRatio = (smoothedSoftPersonRatio *
              (1.0 - PersonDetectorConfig.RATIO_SMOOTHING_ALPHA)) +
          (lastSoftPersonRatio * PersonDetectorConfig.RATIO_SMOOTHING_ALPHA);
    }

    // Smoothed evidence — the stable value UI/business logic reads.
    presenceScore = math.max(
      smoothedPersonRatio,
      smoothedSoftPersonRatio * PersonDetectorConfig.SOFT_RATIO_SCORE_WEIGHT,
    );

    // --- Detection decision: two instant escape hatches, then hysteresis. ---

    // (1) Instant-leave: near-empty frame. Trust the un-smoothed signal so we
    // drop immediately, and RESET the smoothed history to raw — otherwise a long
    // run of high presence would keep presenceScore "warm" for several frames
    // after the person is already gone.
    if (currentScore < PersonDetectorConfig.MIN_PERSON_RATIO_EXIT) {
      smoothedPersonRatio = lastPersonRatio;
      smoothedSoftPersonRatio = lastSoftPersonRatio;
      presenceScore = currentScore;
      personDetected = false;
      return;
    }

    // (2) Instant-enter: clearly a person this frame → detected, no waiting.
    if (currentScore >= PersonDetectorConfig.MIN_PERSON_RATIO) {
      personDetected = true;
      return;
    }

    // (3) Ambiguous middle (EXIT ≤ currentScore < ENTER): decide on the SMOOTHED
    // score with a two-threshold hysteresis band so the state can't flicker at
    // the boundary. Already in? hold until it falls below EXIT (0.02). Out?
    // don't flip until it clears the higher ENTER bar (0.03).
    if (personDetected) {
      personDetected =
          presenceScore >= PersonDetectorConfig.MIN_PERSON_RATIO_EXIT;
    } else {
      personDetected = presenceScore >= PersonDetectorConfig.MIN_PERSON_RATIO;
    }
  }

  /// Free native resources. Call when exercise is activated or app disposes.
  @override
  Future<void> close() async {
    _isClosed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _disposeChannelQuietly();
  }

  Future<void> _disposeChannelQuietly() async {
    try {
      await _channel.stop();
    } catch (_) {
      // Native segmentation may be unavailable in tests or unsupported builds.
    }
    try {
      await _channel.dispose();
    } catch (_) {
      // Best effort only.
    }
  }
}
