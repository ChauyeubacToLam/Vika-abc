/* =========================================================================
    PersonDetector — "Is there a real person in frame?"

    Uses native ML Kit Selfie Segmentation aggregate events. Native code counts
    mask pixels and sends ratios only; Dart keeps smoothing, presence blending,
    and hysteresis so behavior stays aligned with the previous Flutter wrapper.
    ========================================================================= */

import 'dart:async';

import 'segmentation_channel.dart';

class PersonDetectorConfig {
  /// Minimum percentage of frame pixels that must be "person" (0.0–1.0)
  static const double MIN_PERSON_RATIO = 0.5;

  /// Lower threshold to leave the detected state.
  /// Creates hysteresis so the state does not flicker frame-to-frame.
  static const double MIN_PERSON_RATIO_EXIT = 0.30;

  /// Per-pixel confidence threshold to count as "person"
  static const double PIXEL_CONFIDENCE_THRESHOLD = 0.92;

  /// A softer threshold used to estimate body coverage when the mask is noisy.
  static const double SOFT_PIXEL_CONFIDENCE_THRESHOLD = 0.55;

  /// Run segmentation at a limited cadence to avoid blocking the pose stream.
  static const Duration MIN_PROCESS_INTERVAL = Duration(milliseconds: 140);

  /// EMA smoothing for person coverage.
  static const double RATIO_SMOOTHING_ALPHA = 0.28;
}

class PersonDetector {
  final SegmentationChannel _channel;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _isStarted = false;
  bool _isClosed = false;

  /// Last computed person ratio (0.0–1.0) for debug display
  double lastPersonRatio = 0.0;

  /// Smoothed ratio used by UI/business logic.
  double smoothedPersonRatio = 0.0;

  /// Blend of high-confidence body coverage and softer body coverage.
  double presenceScore = 0.0;

  /// Whether a person was detected in the last processed frame
  bool personDetected = false;

  PersonDetector({SegmentationChannel? channel})
      : _channel = channel ?? SegmentationChannel() {
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_isClosed || _isStarted) return;
    _isStarted = true;

    _subscription = _channel.eventStream.listen(
      _handleSegmentationEvent,
      onError: (_) {
        // If segmentation fails, do not hard-block the workout.
      },
    );

    await _channel.initialize(
      pixelConfidenceThreshold: PersonDetectorConfig.PIXEL_CONFIDENCE_THRESHOLD,
      softPixelConfidenceThreshold:
          PersonDetectorConfig.SOFT_PIXEL_CONFIDENCE_THRESHOLD,
      minProcessIntervalMs:
          PersonDetectorConfig.MIN_PROCESS_INTERVAL.inMilliseconds,
    );
    if (_isClosed) {
      await _channel.dispose();
      return;
    }
    await _channel.start();
  }

  /// Returns the cached native segmentation state.
  /// The optional argument keeps existing call sites source-compatible.
  Future<bool> detect([Object? _]) async {
    if (!_isStarted && !_isClosed) {
      await _initialize();
    }
    return personDetected;
  }

  void _handleSegmentationEvent(Map<String, dynamic> event) {
    final personRatio = (event['personRatio'] as num?)?.toDouble();
    final softRatio = (event['softPersonRatio'] as num?)?.toDouble();
    if (personRatio == null || softRatio == null) {
      return;
    }

    lastPersonRatio = personRatio;

    smoothedPersonRatio = smoothedPersonRatio == 0.0
        ? lastPersonRatio
        : (smoothedPersonRatio *
                (1.0 - PersonDetectorConfig.RATIO_SMOOTHING_ALPHA)) +
            (lastPersonRatio * PersonDetectorConfig.RATIO_SMOOTHING_ALPHA);

    presenceScore = (smoothedPersonRatio * 0.75) + (softRatio * 0.25);

    final previouslyDetected = personDetected;

    if (personDetected) {
      personDetected =
          presenceScore >= PersonDetectorConfig.MIN_PERSON_RATIO_EXIT;
    } else {
      personDetected = presenceScore >= PersonDetectorConfig.MIN_PERSON_RATIO;
    }

    if (personDetected != previouslyDetected) {
      final tag = personDetected ? 'PRESENCE_GAINED' : 'PRESENCE_LOST';
      unawaited(
        _channel.debugLog(
          '$tag ratio=${lastPersonRatio.toStringAsFixed(3)} '
          'smoothed=${smoothedPersonRatio.toStringAsFixed(3)} '
          'score=${presenceScore.toStringAsFixed(3)}',
        ),
      );
    }
  }

  /// Free native resources. Call when exercise is activated or app disposes.
  Future<void> close() async {
    _isClosed = true;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel.stop();
    } finally {
      await _channel.dispose();
    }
  }
}
