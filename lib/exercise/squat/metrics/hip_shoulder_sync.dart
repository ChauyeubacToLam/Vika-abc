/* =========================================================================
   Metric 5: Hip-Shoulder Rise Synchrony (Good Morning Detection)
   Priority: IMPORTANT — Ship Month 2-3
   
   During ascent: detects if hips rise significantly faster than shoulders.
   This is the "good morning squat" pattern — hips shoot up while chest
   drops forward, dumping shear force onto lumbar spine.
   
   APPROACH:
   - Only track during FIRST 50% of ascending phase (signal is strongest
     early in ascent; normalizes near standing).
   - Compare hip vs shoulder upward velocity over a sliding window.
   - Ratio = hipSpeed / shoulderSpeed.
   
   COORDINATE SYSTEM:
   ML Kit Y increases DOWNWARD. During ascent, both hip and shoulder Y
   values DECREASE (moving up). We compute speed as positive-upward
   by using (first - last) so higher = faster upward movement.
   
   Vietnamese Adjustments:
   - Group 1 males (long legs, short torso) are mechanically prone to
     hip-dominant ascent. Expand Good to 0.8-1.4 for this body type.
   - For bodyweight squats, frame as coaching cue, not safety alert.
   ========================================================================= */

import 'package:vinafit_mobile/utils/debouncer.dart';

import 'squat_metric_base.dart';
import '../squat.dart';

class HipShoulderSyncConfig {
  /// Good: hips and shoulders rise together.
  static const double RATIO_GOOD_MAX = 1.3;

  /// Warning: mild hip-leading pattern.
  static const double RATIO_WARNING_MAX = 1.8;

  /// Above this = clear good morning pattern (error).
  /// (anything > RATIO_WARNING_MAX)

  /// Sliding window size in frames for velocity calculation.
  static const int WINDOW_SIZE = 3; // ~0.1s at 30fps

  /// Maximum frames to evaluate during ascent.
  /// Only evaluate first ~50% of ascent to catch the pattern early.
  /// At 30fps, 15 frames ≈ 0.5s — covers the critical first half
  /// of a typical 1-1.5s ascent.
  static const int MAX_ASCENT_FRAMES = 15;

  /// Minimum shoulder speed to compute ratio (avoids divide-by-near-zero).
  /// If shoulders barely move while hips shoot up, that's the worst case
  /// and we flag it directly without computing ratio.
  static const double MIN_SHOULDER_SPEED = 0.5;

  /// Consecutive warning frames before confirming fault.
  static const int CONFIRM_FRAMES = 3;
}

class HipShoulderSyncMetric extends SquatMetricBase {
  @override
  String get name => 'HipShoulderSync';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Sliding windows for velocity calculation
  final List<double> _hipYWindow = [];
  final List<double> _shoulderYWindow = [];

  //Debouncer for clear good morning pattern (hip speed >> shoulder speed)
  final Debouncer _warningEdgeDebouncer =
      Debouncer(requiredFrames: HipShoulderSyncConfig.CONFIRM_FRAMES);
  final Debouncer _warningMaxDebouncer =
      Debouncer(requiredFrames: HipShoulderSyncConfig.CONFIRM_FRAMES);
  final Debouncer _warningMildDebouncer =
      Debouncer(requiredFrames: HipShoulderSyncConfig.CONFIRM_FRAMES);

  // Ascent tracking
  int _ascentFrameCount = 0;
  bool _faultLogged = false;

  // Peak ratio this rep (for post-rep analysis)
  double _peakRatio = 0.0;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  Map<String, String> update(RepContext ctx) {
    final feedback = <String, String>{};

    if (ctx.squatState != SquatState.ascending) {
      return feedback;
    }

    _ascentFrameCount++;

    // Only evaluate first 50% of ascent — signal normalizes near standing
    if (_ascentFrameCount > HipShoulderSyncConfig.MAX_ASCENT_FRAMES) {
      _debugData['syncStatus'] = 'past window';
      return feedback;
    }

    // Add to sliding windows
    _hipYWindow.add(ctx.hipY);
    _shoulderYWindow.add(ctx.shoulderY);

    // Trim to window size
    while (_hipYWindow.length > HipShoulderSyncConfig.WINDOW_SIZE) {
      _hipYWindow.removeAt(0);
    }
    while (_shoulderYWindow.length > HipShoulderSyncConfig.WINDOW_SIZE) {
      _shoulderYWindow.removeAt(0);
    }

    // Need full window to compute velocity
    if (_hipYWindow.length < HipShoulderSyncConfig.WINDOW_SIZE) {
      _debugData['syncStatus'] = 'filling window';
      return feedback;
    }

    // Compute upward speed (positive = moving up)
    // ML Kit Y increases downward, so (first - last) = upward movement
    final frameCount = _hipYWindow.length - 1;
    final hipSpeed = (_hipYWindow.first - _hipYWindow.last) / frameCount;
    final shoulderSpeed =
        (_shoulderYWindow.first - _shoulderYWindow.last) / frameCount;

    _debugData['hipSpeed'] = hipSpeed.toStringAsFixed(2);
    _debugData['shoulderSpeed'] = shoulderSpeed.toStringAsFixed(2);

    // Edge case: shoulders barely moving while hips shoot up
    // This IS the good morning pattern — worst case
    if (_warningEdgeDebouncer.update(
        shoulderSpeed < HipShoulderSyncConfig.MIN_SHOULDER_SPEED &&
            hipSpeed > HipShoulderSyncConfig.MIN_SHOULDER_SPEED)) {
      _debugData['syncStatus'] = 'ERROR (shoulders still, hips up)';
      _maybeLogFault(ctx, 'Shoulders stalled while hips rose');
      feedback['Sync'] = 'Drive chest up!';
      return feedback;
    }

    // Normal case: compute ratio
    if (shoulderSpeed < HipShoulderSyncConfig.MIN_SHOULDER_SPEED) {
      // Both barely moving — no meaningful data
      _debugData['syncStatus'] = 'minimal movement';
      return feedback;
    }

    final ratio = hipSpeed / shoulderSpeed;
    if (ratio > _peakRatio) _peakRatio = ratio;

    _debugData['syncRatio'] = ratio.toStringAsFixed(2);
    _debugData['peakSyncRatio'] = _peakRatio.toStringAsFixed(2);

    if (_warningMaxDebouncer
        .update(ratio > HipShoulderSyncConfig.RATIO_WARNING_MAX)) {
      // Clear good morning pattern — hips rising much faster than shoulders
      _debugData['syncStatus'] = 'ERROR (hip-leading)';
      _maybeLogFault(ctx, 'Hips rising much faster than shoulders');
      feedback['Sync'] = 'Drive chest up!';
    } else if (_warningMildDebouncer
        .update(ratio > HipShoulderSyncConfig.RATIO_GOOD_MAX)) {
      // Warning: mild hip-leading pattern
      _debugData['syncStatus'] = 'WARNING';
      _maybeLogFault(ctx, 'Hips rising abit faster than shoulders');
      feedback['Sync'] = 'Try to keep chest up';
    } else {
      // Good sync — reset warning counter
      _debugData['syncStatus'] = 'good';
      feedback['Sync'] = 'Good sync';
    }

    return feedback;
  }

  void _maybeLogFault(RepContext ctx, String message) {
    if (_faultLogged) return; // One fault per rep max
    _faultLogged = true;

    final phase = ctx.squatState.toString().split('.').last.toUpperCase();
    _faults.add(FaultRecord(
      phase: phase,
      type: 'HipShoulderSync',
      message: message,
      affectsForm: true,
    ));
  }

  @override
  void reset() {
    _hipYWindow.clear();
    _shoulderYWindow.clear();
    _ascentFrameCount = 0;
    _faultLogged = false;
    _peakRatio = 0.0;
    _faults.clear();
    _debugData.clear();
  }
}
