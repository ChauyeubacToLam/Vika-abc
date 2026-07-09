/* =========================================================================
   Metric 1.3: Eccentric Speed Control (Core Engagement Proxy)
   Priority: 🟠 IMPORTANT (core engagement proxy, lumbopelvic control)

   What it detects:
     Loss of lumbopelvic control manifesting as uncontrolled, rapid descent.
     When core bracing fails, users 'speed through' the eccentric phase,
     allowing hips to plummet while shoulders stay stationary.

   Why it matters (Colonna 2025 SBE narrative review):
     Repeated bridging with uncontrolled lordosis and APT may increase
     lumbar compression. Rapid descent is the closest proxy for detecting
     anterior pelvic tilt without ASIS/PSIS landmarks.

   Landmarks & Calculation:
     Primary:   HIP y-coordinate velocity during descending state.
                Velocity is already smoothed by a 5-7 frame rolling window
                in GluteBridge._computeHipVelocity().
     Secondary: Eccentric (topHold→bottom) vs concentric (bottom→topHold)
                duration ratio. A controlled eccentric >= 1.5ˣ concentric.

   False positive risk — HIGH:
     Users doing intentional speed reps will trigger false alerts.
     Users shifting upper back on floor for comfort create rapid torso
     angle change. Frame feedback as pacing correction ('Control your
     descent') NOT anatomical diagnosis. Encourage rather than diagnose.

   Architecture note:
     The rep is counted at DESCENDING → BOTTOM. The eccentric phase completes
     at that same transition, so this metric now accurately assigns its faults
     to the current rep, avoiding the previous one-rep lag. Live coaching
     is delivered with zero lag via update() during descent.
   ========================================================================= */

import 'glute_bridge_metric_base.dart';
import '../glute_bridge.dart';
import '../../../../utils/debouncer.dart';

class SpeedControlConfig {
  // Minimum acceptable eccentric-to-concentric duration ratio.
  static const double MIN_ECCENTRIC_RATIO = 1.1;

  // Velocity thresholds during descent (pixels/frame, positive = falling).
  // In screen coordinates hip FALLING → velocity POSITIVE.
  static const double RAPID_VELOCITY_WARNING = 0.09; // affectsForm = false
  static const double RAPID_VELOCITY_ERROR = 0.16; // affectsForm = true

  // Frames of sustained rapid velocity before triggering live coaching.
  static const int RAPID_DEBOUNCE_FRAMES = 5;
}

class SpeedControlMetric extends GluteBridgeMetricBase {
  @override
  String get name => 'SpeedControl';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Debouncer for live rapid-descent coaching during update().
  final Debouncer _rapidDebouncer =
      Debouncer(requiredFrames: SpeedControlConfig.RAPID_DEBOUNCE_FRAMES);

  // Prevent instruction and fault spam — one set per descent phase.
  bool _liveInstructionShown = false;
  bool _velocityFaultAdded = false;

  // Peak descent velocity seen this eccentric phase.
  double _peakDescentVelocity = 0.0;

  // --- Duration tracking ---
  int? _ascentStartMs; // bottom → ascending
  int? _descentStartMs; // topHold → descending (eccentric start)

  double? _concentricDuration; // seconds
  double? _eccentricDuration; // seconds

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /* -----------------------------------------------------------------------
     Per-frame update — live velocity monitoring during eccentric phase.
     Only active during descending state.
     ----------------------------------------------------------------------- */
  @override
  void update(RepContext ctx) {
    if (ctx.state != GluteBridgeState.descending) return;

    final scale = ctx.scaleFactor;
    if (scale == null || scale <= 1e-6) return;
    final double vel = ctx.hipVelocity / scale;

    if (vel > _peakDescentVelocity) _peakDescentVelocity = vel;

    _debugData['descentVel'] = '+${vel.toStringAsFixed(2)}';
    _debugData['peakDescentVel'] =
        '+${_peakDescentVelocity.toStringAsFixed(2)}';

    final bool isRapid = vel >= SpeedControlConfig.RAPID_VELOCITY_WARNING;

    if (_rapidDebouncer.update(isRapid)) {
      // Live coaching — once per descent.
      if (!_liveInstructionShown) {
        ctx.resultIssues.addInstruction(
          'bottom',
          'SpeedControl',
          'Kiểm soát hạ hông — không để rơi tự do',
        );
        _liveInstructionShown = true;
      }
    }
  }

  /* -----------------------------------------------------------------------
     State transition hook — records timestamps for duration comparison.
     ----------------------------------------------------------------------- */
  @override
  void onStateTransition(
      GluteBridgeState from, GluteBridgeState to, int timestampMs) {
    switch (to) {
      case GluteBridgeState.ascending:
        _ascentStartMs = timestampMs;
        _concentricDuration = null; // Clear previous concentric duration
        // Reset eccentric tracking for new rep cycle.
        _rapidDebouncer.reset();
        _liveInstructionShown = false;
        _velocityFaultAdded = false;
        _peakDescentVelocity = 0.0;
        break;

      case GluteBridgeState.topHold:
        if (_ascentStartMs != null) {
          _concentricDuration = (timestampMs - _ascentStartMs!) / 1000.0;
          _debugData['concentricDur'] = _concentricDuration!.toStringAsFixed(2);
        }
        break;

      case GluteBridgeState.descending:
        if (from == GluteBridgeState.ascending && _ascentStartMs != null) {
          _concentricDuration = (timestampMs - _ascentStartMs!) / 1000.0;
          _debugData['concentricDur'] = _concentricDuration!.toStringAsFixed(2);
        }
        _descentStartMs = timestampMs;
        break;

      case GluteBridgeState.bottom:
        // Handled in checkRepCompletion now
        break;
    }
  }

  /* -----------------------------------------------------------------------
     Duration ratio evaluation — called at DESCENDING → BOTTOM transition.
     ----------------------------------------------------------------------- */
  void checkRepCompletion(int timestampMs) {
    if (_descentStartMs != null) {
      _eccentricDuration = (timestampMs - _descentStartMs!) / 1000.0;
      _debugData['eccentricDur'] = _eccentricDuration!.toStringAsFixed(2);

      // Evaluate outright speed error using the peak recorded velocity
      if (_peakDescentVelocity >= SpeedControlConfig.RAPID_VELOCITY_ERROR) {
        _faults.add(FaultRecord(
          phase: 'descending',
          type: 'speed_control',
          message: 'Hạ hông quá nhanh — siết cơ lõi để kiểm soát',
          affectsForm: true,
        ));
        _velocityFaultAdded = true;
      } else if (_liveInstructionShown) {
        _faults.add(FaultRecord(
          phase: 'descending',
          type: 'speed_control',
          message: 'Kiểm soát tốc độ hạ hông để bảo vệ lưng',
          affectsForm: false,
        ));
        _velocityFaultAdded = true;
      }

      _evaluateRatio();
    }
  }

  void _evaluateRatio() {
    if (_eccentricDuration == null || _concentricDuration == null) return;
    if (_concentricDuration! < 0.1) return; // avoid division noise

    final double ratio = _eccentricDuration! / _concentricDuration!;
    _debugData['eccConRatio'] = ratio.toStringAsFixed(2);

    if (ratio < SpeedControlConfig.MIN_ECCENTRIC_RATIO &&
        !_velocityFaultAdded) {
      // Only add if the velocity debouncer hasn't already flagged it,
      // to avoid double-faulting the same descent.
      _faults.add(FaultRecord(
        phase: 'descending',
        type: 'speed_control',
        message: 'Hạ hông chậm lại — mục tiêu kiểm soát gấp đôi thời gian nâng',
        affectsForm: false, // informational pacing cue
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _rapidDebouncer.reset();
    _liveInstructionShown = false;
    _velocityFaultAdded = false;
    _peakDescentVelocity = 0.0;
    _descentStartMs = null;
    _eccentricDuration = null;
    _ascentStartMs = null;
    _concentricDuration = null;
  }
}
