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

import 'package:vika/utils/debouncer.dart';

import 'squat_metric_base.dart';
import '../squat.dart';

class HipShoulderSyncConfig {
  /// Good: hips and shoulders rise together.
  static const double RATIO_GOOD_MAX = 0.85;

  /// Warning: mild hip-leading pattern.
  static const double RATIO_WARNING_MAX = 1.0;

  /// Sliding window size in frames for velocity calculation.
  static const int WINDOW_SIZE = 3; // ~0.1s at 30fps

  /// Maximum frames to evaluate during ascent.
  static const int MAX_ASCENT_FRAMES = 20;

  /// Minimum shoulder speed to compute ratio (avoids divide-by-near-zero).
  static const double MIN_SHOULDER_SPEED = 0.6;

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

  final Debouncer _warningEdgeDebouncer =
      Debouncer(requiredFrames: HipShoulderSyncConfig.CONFIRM_FRAMES);
  final Debouncer _warningMaxDebouncer =
      Debouncer(requiredFrames: HipShoulderSyncConfig.CONFIRM_FRAMES);
  final Debouncer _warningMildDebouncer =
      Debouncer(requiredFrames: HipShoulderSyncConfig.CONFIRM_FRAMES);

  int _ascentFrameCount = 0;
  bool _faultLogged = false;

  /// Prevent instruction spam — only set coaching once per rep.
  bool _instructionSet = false;

  double _peakRatio = 0.0;
  double? _ratio;
  MetricStatus _status = MetricStatus.pass;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _ratio;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: HipShoulderSyncConfig.RATIO_GOOD_MAX,
        faultAbove: HipShoulderSyncConfig.RATIO_WARNING_MAX,
      );

  @override
  MetricStatus get status => _status;

  @override
  void update(RepContext ctx) {
    if (ctx.squatState != SquatState.ascending) {
      _status = MetricStatus.pass;
      return;
    }

    _ascentFrameCount++;

    // Only evaluate first 50% of ascent — signal normalizes near standing
    if (_ascentFrameCount > HipShoulderSyncConfig.MAX_ASCENT_FRAMES) {
      _status = MetricStatus.pass;
      _debugData['syncStatus'] = 'past window';
      return;
    }

    // Add to sliding windows
    _hipYWindow.add(ctx.hipY);
    _shoulderYWindow.add(ctx.shoulderY);

    while (_hipYWindow.length > HipShoulderSyncConfig.WINDOW_SIZE) {
      _hipYWindow.removeAt(0);
    }
    while (_shoulderYWindow.length > HipShoulderSyncConfig.WINDOW_SIZE) {
      _shoulderYWindow.removeAt(0);
    }

    if (_hipYWindow.length < HipShoulderSyncConfig.WINDOW_SIZE) {
      _status = MetricStatus.pass;
      _debugData['syncStatus'] = 'filling window';
      return;
    }

    final frameCount = _hipYWindow.length - 1;
    final hipSpeed = (_hipYWindow.first - _hipYWindow.last) / frameCount;
    final shoulderSpeed =
        (_shoulderYWindow.first - _shoulderYWindow.last) / frameCount;

    _debugData['hipSpeed'] = hipSpeed;
    _debugData['shoulderSpeed'] = shoulderSpeed;

    final ratio = shoulderSpeed.abs() < HipShoulderSyncConfig.MIN_SHOULDER_SPEED
        ? hipSpeed / HipShoulderSyncConfig.MIN_SHOULDER_SPEED
        : hipSpeed / shoulderSpeed;
    _ratio = ratio;
    if (ratio > _peakRatio) _peakRatio = ratio;
    _debugData['syncRatio'] = ratio;
    _debugData['peakSyncRatio'] = _peakRatio;

    // Edge case: shoulders barely moving while hips shoot up
    if (_warningEdgeDebouncer.update(
        shoulderSpeed < HipShoulderSyncConfig.MIN_SHOULDER_SPEED &&
            hipSpeed > HipShoulderSyncConfig.MIN_SHOULDER_SPEED)) {
      _status = MetricStatus.fault;
      _debugData['syncStatus'] = 'ERROR (shoulders still, hips up)';
      _maybeLogFault(ctx, 'Shoulders stalled while hips rose');
      ctx.resultIssues.feedback['Sync'] = 'Drive chest up!';
      _maybeSetInstruction(ctx, 'Shoulders barely moved, drive chest up!');
      return;
    }

    if (shoulderSpeed < HipShoulderSyncConfig.MIN_SHOULDER_SPEED) {
      _status = MetricStatus.pass;
      _debugData['syncStatus'] = 'minimal movement';
      return;
    }

    if (_warningMaxDebouncer
        .update(ratio > HipShoulderSyncConfig.RATIO_WARNING_MAX)) {
      _status = MetricStatus.fault;
      _debugData['syncStatus'] = 'ERROR (hip-leading)';
      _maybeLogFault(ctx, 'Hips rising much faster than shoulders');
      ctx.resultIssues.feedback['Sync'] = 'Drive chest up!';
      _maybeSetInstruction(
          ctx, 'Hips too fast, move hips and shoulders together');
    } else if (_warningMildDebouncer
        .update(ratio > HipShoulderSyncConfig.RATIO_GOOD_MAX)) {
      _status = MetricStatus.near;
      _debugData['syncStatus'] = 'WARNING';
      _maybeLogFault(ctx, 'Hips rising a bit faster than shoulders');
      ctx.resultIssues.feedback['Sync'] = 'Try to keep chest up';
      _maybeSetInstruction(ctx, 'Hips a bit fast, try keeping chest up');
    } else {
      _status = MetricStatus.pass;
      _debugData['syncStatus'] = 'good';
      ctx.resultIssues.feedback['Sync'] = 'Good sync';
    }
  }

  void _maybeLogFault(RepContext ctx, String message) {
    if (_faultLogged) return;
    _faultLogged = true;

    final phase = ctx.squatState.toString().split('.').last.toUpperCase();
    _faults.add(FaultRecord(
      phase: phase,
      type: 'HipShoulderSync',
      message: message,
      affectsForm: true,
      voiceMessage: null,
      priority: SquatFaultVoicePriority.hipShoulderSync,
    ));
  }

  /// Set instruction once per rep — avoids overwriting every frame.
  void _maybeSetInstruction(RepContext ctx, String message) {
    if (_instructionSet) return;
    _instructionSet = true;
    ctx.resultIssues.addInstruction('standing', 'Sync', message);
  }

  @override
  void reset() {
    _hipYWindow.clear();
    _shoulderYWindow.clear();
    _ascentFrameCount = 0;
    _faultLogged = false;
    _instructionSet = false;
    _peakRatio = 0.0;
    _ratio = null;
    _status = MetricStatus.pass;
    _faults.clear();
    _debugData.clear();
  }
}
