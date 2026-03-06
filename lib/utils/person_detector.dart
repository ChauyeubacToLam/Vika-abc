/* =========================================================================
   PersonDetector — "Is there a real person in frame?"

   Uses ML Kit Selfie Segmentation to get a per-pixel confidence mask.
   This version adds throttling + hysteresis so person re-checking feels
   smoother during live exercise and camera jitter.
   ========================================================================= */

import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

class PersonDetectorConfig {
  /// Minimum percentage of frame pixels that must be "person" (0.0–1.0)
  static const double MIN_PERSON_RATIO = 0.5;

  /// Lower threshold to leave the detected state.
  /// Creates hysteresis so the state does not flicker frame-to-frame.
  static const double MIN_PERSON_RATIO_EXIT = 0.20;

  /// Per-pixel confidence threshold to count as "person"
  static const double PIXEL_CONFIDENCE_THRESHOLD = 0.92;

  /// A softer threshold used to estimate body coverage when the mask is noisy.
  static const double SOFT_PIXEL_CONFIDENCE_THRESHOLD = 0.35;

  /// Run segmentation at a limited cadence to avoid blocking the pose stream.
  static const Duration MIN_PROCESS_INTERVAL = Duration(milliseconds: 140);

  /// EMA smoothing for person coverage.
  static const double RATIO_SMOOTHING_ALPHA = 0.28;
}

class PersonDetector {
  late final SelfieSegmenter _segmenter;
  bool _isProcessing = false;
  DateTime? _lastProcessedAt;

  /// Last computed person ratio (0.0–1.0) for debug display
  double lastPersonRatio = 0.0;

  /// Smoothed ratio used by UI/business logic.
  double smoothedPersonRatio = 0.0;

  /// Blend of high-confidence body coverage and softer body coverage.
  double presenceScore = 0.0;

  /// Whether a person was detected in the last processed frame
  bool personDetected = false;

  PersonDetector() {
    _segmenter = SelfieSegmenter(
      mode: SegmenterMode.stream, // Temporal smoothing between frames
      enableRawSizeMask: true, // Smaller mask = faster processing
    );
  }

  /// Process an InputImage and return whether a person is detected.
  /// When called too often, returns the cached result immediately.
  Future<bool> detect(InputImage inputImage) async {
    final now = DateTime.now();
    if (_isProcessing) return personDetected;
    if (_lastProcessedAt != null &&
        now.difference(_lastProcessedAt!) <
            PersonDetectorConfig.MIN_PROCESS_INTERVAL) {
      return personDetected;
    }

    _isProcessing = true;
    _lastProcessedAt = now;

    try {
      final mask = await _segmenter.processImage(inputImage);
      if (mask == null) {
        lastPersonRatio = 0.0;
        smoothedPersonRatio *= 0.85;
        presenceScore = smoothedPersonRatio;
        personDetected = false;
        return false;
      }

      final confidences = mask.confidences;

      final totalPixels = confidences.length;

      if (totalPixels == 0) {
        lastPersonRatio = 0.0;
        smoothedPersonRatio *= 0.85;
        presenceScore = smoothedPersonRatio;
        personDetected = false;
        return false;
      }

      int personPixels = 0;
      int softPersonPixels = 0;
      for (final confidence in confidences) {
        if (confidence >= PersonDetectorConfig.PIXEL_CONFIDENCE_THRESHOLD) {
          personPixels++;
        }
        if (confidence >=
            PersonDetectorConfig.SOFT_PIXEL_CONFIDENCE_THRESHOLD) {
          softPersonPixels++;
        }
      }

      lastPersonRatio = personPixels / totalPixels;
      final softRatio = softPersonPixels / totalPixels;

      smoothedPersonRatio = smoothedPersonRatio == 0.0
          ? lastPersonRatio
          : (smoothedPersonRatio *
                  (1.0 - PersonDetectorConfig.RATIO_SMOOTHING_ALPHA)) +
              (lastPersonRatio * PersonDetectorConfig.RATIO_SMOOTHING_ALPHA);

      presenceScore = (smoothedPersonRatio * 0.75) + (softRatio * 0.25);

      if (personDetected) {
        personDetected =
            presenceScore >= PersonDetectorConfig.MIN_PERSON_RATIO_EXIT;
      } else {
        personDetected = presenceScore >= PersonDetectorConfig.MIN_PERSON_RATIO;
      }

      return personDetected;
    } catch (e) {
      // If segmentation fails, don't hard-block the workout.
      return personDetected;
    } finally {
      _isProcessing = false;
    }
  }

  /// Free native resources. Call when exercise is activated or app disposes.
  Future<void> close() async {
    await _segmenter.close();
  }
}
