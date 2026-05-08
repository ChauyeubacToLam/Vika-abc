import 'dart:collection';
import '../utils/debouncer.dart';

/// Detects sudden drops in a presence-like signal (0.0–1.0) relative to its
/// own running baseline. Self-calibrates: if the signal stabilizes at 0.6
/// (e.g. push-up close to camera with cropped legs), 0.6 becomes the
/// baseline and only further drops trigger anomaly.
///
/// Used as the secondary gate in HYBRID person-leaving detection. Two
/// instances live on `ExerciseBase`: one fed avg pose-landmark presence,
/// one fed segmentation presence score.
class PresenceAnomalyDetector {
  final Debouncer _anomalyDebouncer;
  PresenceAnomalyDetector({
    this.longWindowFrames = 60,
    this.shortWindowFrames = 10,
    this.anomalyDelta = 0.15,
    this.confirmFrames = 3,
  })  : assert(longWindowFrames > shortWindowFrames),
        assert(anomalyDelta > 0 && anomalyDelta <= 1.0),
        assert(confirmFrames >= 1),
        _anomalyDebouncer = Debouncer(requiredFrames: confirmFrames);

  final int longWindowFrames;
  final int shortWindowFrames;
  final double anomalyDelta;
  final int confirmFrames;

  final Queue<double> _longWindow = ListQueue<double>();
  final Queue<double> _shortWindow = ListQueue<double>();
  double _longSum = 0.0;
  double _shortSum = 0.0;
  bool _anomalyConfirmed = false;

  bool get isAnomalyConfirmed => _anomalyConfirmed;

  /// True once the long window has filled. Before warm-up, no anomaly fires.
  bool get isWarmedUp => _longWindow.length >= longWindowFrames;

  double get baseline =>
      _longWindow.isEmpty ? 0.0 : _longSum / _longWindow.length;

  double get recent =>
      _shortWindow.isEmpty ? 0.0 : _shortSum / _shortWindow.length;

  double get currentDelta => baseline - recent;

  /// Push a new sample. Call once per pose frame.
  void update(double sample) {
    _longSum += sample;
    _longWindow.addLast(sample);
    if (_longWindow.length > longWindowFrames) {
      _longSum -= _longWindow.removeFirst();
    }

    _shortSum += sample;
    _shortWindow.addLast(sample);
    if (_shortWindow.length > shortWindowFrames) {
      _shortSum -= _shortWindow.removeFirst();
    }

    if (!isWarmedUp) {
      _anomalyConfirmed = false;
      return;
    }

    _anomalyConfirmed = _anomalyDebouncer.update(currentDelta > anomalyDelta);
  }

  /// Clear all state. Call on exercise state transitions and pause/resume.
  void reset() {
    _longWindow.clear();
    _shortWindow.clear();
    _longSum = 0.0;
    _shortSum = 0.0;
    _anomalyDebouncer.reset();
    _anomalyConfirmed = false;
  }
}
