/* =========================================================================
   PersonDetector — "Is there a real person in frame?"
   
   Uses ML Kit Selfie Segmentation to get a per-pixel confidence mask.
   Counts pixels with confidence > 0.5 and checks if enough of the
   frame contains a person.
   
   Usage:
   - Only run during ExerciseState.notActivated (gate before activation)
   - Uses stream mode for temporal smoothing between frames
   - Call close() when done to free native resources
   
   Replaces all heuristic object filters (proportions, symmetry, etc.)
   with a single ML-based check.
   ========================================================================= */

import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PersonDetectorConfig {
  /// Minimum percentage of frame pixels that must be "person" (0.0–1.0)
  /// 5% is low — even a partial body (upper half for plank setup) should hit this.
  /// Adjust after testing with real camera angles.
  static const double MIN_PERSON_RATIO = 0.05;

  /// Per-pixel confidence threshold to count as "person"
  static const double PIXEL_CONFIDENCE_THRESHOLD = 0.98;
}

class PersonDetector {
  late final SelfieSegmenter _segmenter;
  bool _isProcessing = false;

  /// Last computed person ratio (0.0–1.0) for debug display
  double lastPersonRatio = 0.0;

  /// Whether a person was detected in the last processed frame
  bool personDetected = false;

  PersonDetector() {
    _segmenter = SelfieSegmenter(
      mode: SegmenterMode.stream, // Temporal smoothing between frames
      enableRawSizeMask: true, // Smaller mask = faster processing
    );
  }

  /// Process an InputImage and return whether a person is detected.
  /// Returns null if already processing (skip frame, don't block).
  Future<bool?> detect(InputImage inputImage) async {
    if (_isProcessing) return null; // Drop frame
    _isProcessing = true;

    try {
      final mask = await _segmenter.processImage(inputImage);
      if (mask == null) {
        lastPersonRatio = 0.0;
        personDetected = false;
        return false;
      }

      final confidences = mask.confidences;

      final totalPixels = confidences.length;

      if (totalPixels == 0) {
        lastPersonRatio = 0.0;
        personDetected = false;
        return false;
      }

      // Count pixels above confidence threshold
      int personPixels = 0;
      for (final confidence in confidences) {
        if (confidence >= PersonDetectorConfig.PIXEL_CONFIDENCE_THRESHOLD) {
          personPixels++;
        }
      }

      lastPersonRatio = personPixels / totalPixels;
      personDetected = lastPersonRatio >= PersonDetectorConfig.MIN_PERSON_RATIO;

      return personDetected;
    } catch (e) {
      // If segmentation fails, don't block — assume person present
      personDetected = true;
      return true;
    } finally {
      _isProcessing = false;
    }
  }

  /// Free native resources. Call when exercise is activated or app disposes.
  Future<void> close() async {
    await _segmenter.close();
  }
}
