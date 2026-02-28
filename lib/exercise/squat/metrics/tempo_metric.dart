// ignore_for_file: constant_identifier_names

/* =========================================================================
   Metric 4: Descent Tempo Control
   Priority: NICE-TO-HAVE — Ship Month 1-2
   
   Measures time for descent vs ascent phase.
   Detects:
   - Uncontrolled dropping (no eccentric control)
   - Bouncing out of the bottom (no pause)
   - Slow grinding ascent (struggling / weak quads)
   
   APPROACH:
   - onStateTransition() records timestamps + calculates durations.
   - update() checks durations per-frame (null-gated) for live feedback.
   - evaluateRep() logs faults + sets coaching instructions for next rep.
   
   LIVE FEEDBACK (in update, fires as soon as data exists):
     Bottom phase    → descent speed check (descentDuration available)
     Ascending phase → bottom hold check (bottomHoldDuration available)
   
   COACHING INSTRUCTIONS (set by evaluateRep, shown during standing):
     All tempo coaching shows during standing — one moment to absorb
     tips before the next rep begins.
   
   Vietnamese Adjustments (Weeks 1-4):
   - Beginners with stiff ankles often descend slowly (3-5s) → ACCEPTABLE
   - Good descent: 2-5s (beginner), tightens to 2-3.5s at Month 4+
   - Frame as "rhythm" not strict timing
   ========================================================================= */

import 'squat_metric_base.dart';
import '../squat.dart';

class TempoConfig {
  /* --- Descent Duration (seconds) --- */
  static const double DESCENT_MIN_GOOD = 0.45;
  static const double DESCENT_MIN_ERROR = 0.35;

  /* --- Bottom Hold (seconds) --- */
  static const double BOTTOM_HOLD_MIN = 0.8;

  /* --- Descent:Ascent Ratio --- */
  static const double RATIO_GOOD = 2.0;
  static const double RATIO_WARNING = 0.5;

  /* --- Ascent Struggle Detection --- */
  static const double ASCENT_STRUGGLE_MULTIPLIER = 2.0;
}

/* =========================================================================
   TempoMetric Main Logic
   ========================================================================= */

class TempoMetric extends SquatMetricBase {
  @override
  String get name => 'Tempo';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // --- Timestamps (milliseconds) ---
  int? _descentStartMs;
  int? _bottomReachedMs;
  int? _ascentStartMs;
  int? _repCompleteMs;

  // --- Computed durations (seconds) ---
  double? _descentDuration;
  double? _ascentDuration;
  double? _bottomHoldDuration;
  double? _descentAscentRatio;

  // --- Public getters ---
  double? get descentDuration => _descentDuration;
  double? get ascentDuration => _ascentDuration;
  double? get bottomHoldDuration => _bottomHoldDuration;
  double? get descentAscentRatio => _descentAscentRatio;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /* -----------------------------------------------------------------------
     STATE TRANSITIONS — record timestamps + compute durations.
     ----------------------------------------------------------------------- */
  @override
  void onStateTransition(SquatState from, SquatState to, int timestampMs) {
    switch (to) {
      case SquatState.descending:
        _descentStartMs = timestampMs;
        break;

      case SquatState.bottom:
        _bottomReachedMs = timestampMs;
        if (_descentStartMs != null) {
          _descentDuration = (timestampMs - _descentStartMs!) / 1000.0;
          _debugData['descentDur'] =
              _descentDuration?.toStringAsFixed(2) ?? '-';
        }
        break;

      case SquatState.ascending:
        _ascentStartMs = timestampMs;
        if (_bottomReachedMs != null) {
          _bottomHoldDuration = (timestampMs - _bottomReachedMs!) / 1000.0;
          _debugData['bottomHold'] =
              _bottomHoldDuration?.toStringAsFixed(2) ?? '-';
        }
        break;

      case SquatState.standing:
        _repCompleteMs = timestampMs;
        if (_ascentStartMs != null) {
          _ascentDuration = (timestampMs - _ascentStartMs!) / 1000.0;
          _debugData['ascentDur'] = _ascentDuration?.toStringAsFixed(2) ?? '-';
        }
        if (_descentDuration != null &&
            _ascentDuration != null &&
            _ascentDuration! > 0.05) {
          _descentAscentRatio = _descentDuration! / _ascentDuration!;
          _debugData['ratio'] = _descentAscentRatio?.toStringAsFixed(2) ?? '-';
        }
        break;
    }
  }

  /* -----------------------------------------------------------------------
     PER-FRAME UPDATE — Live feedback (null-gated, fires once data exists).
     ----------------------------------------------------------------------- */
  @override
  void update(RepContext ctx) {
    // Live check: descent speed (available after entering bottom)
    if (_descentDuration != null) {
      if (_descentDuration! < TempoConfig.DESCENT_MIN_ERROR) {
        ctx.resultIssues.feedback['Tempo'] =
            'Dropping like a rock, control the way down!';
      } else if (_descentDuration! < TempoConfig.DESCENT_MIN_GOOD) {
        ctx.resultIssues.feedback['Tempo'] =
            'Dropping a bit fast, try to slow down!';
      }
    }

    // Live check: bottom hold (available after entering ascending)
    if (_bottomHoldDuration != null &&
        _bottomHoldDuration! < TempoConfig.BOTTOM_HOLD_MIN) {
      ctx.resultIssues.feedback['Tempo'] = 'Not pausing at bottom!';
    }

    if (ctx.resultIssues.feedback['Tempo'] == null) {
      ctx.resultIssues.feedback['Tempo'] = 'Good tempo';
    }
  }

  /* -----------------------------------------------------------------------
     REP COMPLETE — Log faults + set coaching instructions for next rep.
     Called by Squat after final state transition to standing.
     ----------------------------------------------------------------------- */
  void evaluateRep(RepContext ctx) {
    if (_descentDuration == null) {
      _debugData['tempoResult'] = 'no data';
      return;
    }

    const phase = 'REP_COMPLETE';

    // --- 1. Descent duration ---
    if (_descentDuration! < TempoConfig.DESCENT_MIN_ERROR) {
      _logFault(
          phase, 'Dropped too fast (${_descentDuration!.toStringAsFixed(1)}s)');
      ctx.resultIssues.addInstruction(
          'standing', 'Tempo descent', 'Dropped too fast last rep, go slower');
    } else if (_descentDuration! < TempoConfig.DESCENT_MIN_GOOD) {
      _logFault(phase,
          'Descent a bit fast (${_descentDuration!.toStringAsFixed(1)}s)');
      ctx.resultIssues.addInstruction('standing', 'Tempo descent',
          'A bit fast last rep, try 2-3 seconds down');
    }

    // --- 2. Bottom hold (bounce detection) ---
    if (_bottomHoldDuration != null &&
        _bottomHoldDuration! < TempoConfig.BOTTOM_HOLD_MIN) {
      _logFault(phase,
          'Bounced at bottom (${_bottomHoldDuration!.toStringAsFixed(2)}s hold)');
      ctx.resultIssues.addInstruction('standing', 'Tempo bottom hold',
          'Not holding at bottom, pause this time!');
    }

    // --- 3. Descent:Ascent ratio (eccentric control) ---
    if (_descentAscentRatio != null) {
      if (_descentAscentRatio! < TempoConfig.RATIO_WARNING) {
        _logFault(phase,
            'No eccentric control (ratio ${_descentAscentRatio!.toStringAsFixed(1)})');
        ctx.resultIssues.addInstruction(
            'standing', 'Tempo eccentric', 'Control the way down this time');
      } else if (_descentAscentRatio! >
          TempoConfig.RATIO_GOOD + TempoConfig.RATIO_WARNING) {
        ctx.resultIssues.addInstruction(
            'standing', 'Tempo eccentric', 'Drive up with more control');
      }
    }

    // --- 4. Ascent struggle (coaching only, NOT a fault) ---
    if (_descentDuration != null &&
        _ascentDuration != null &&
        _ascentDuration! >
            _descentDuration! * TempoConfig.ASCENT_STRUGGLE_MULTIPLIER) {
      ctx.resultIssues.addInstruction(
          'standing', 'Tempo ascent', 'Drive up with more power!');
    }

    _debugData['tempoResult'] = _faults.isEmpty ? 'good' : 'fault';
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Tempo',
        message: message,
        affectsForm: true,
      ));
    }
  }

  /// Progress 0.0–1.0 of bottom hold countdown. Null if not in bottom.
  double? get bottomHoldProgress {
    if (_bottomReachedMs == null) return null;
    if (_ascentStartMs != null) return null;
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - _bottomReachedMs!) / 1000.0;
    return (elapsed / TempoConfig.BOTTOM_HOLD_MIN).clamp(0.0, 1.0);
  }

  /// Remaining seconds to hold. Counts down from BOTTOM_HOLD_MIN to 0.
  double? get bottomHoldRemaining {
    if (_bottomReachedMs == null) return null;
    if (_ascentStartMs != null) return null;
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - _bottomReachedMs!) / 1000.0;
    return (TempoConfig.BOTTOM_HOLD_MIN - elapsed)
        .clamp(0.0, TempoConfig.BOTTOM_HOLD_MIN);
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _descentStartMs = null;
    _bottomReachedMs = null;
    _ascentStartMs = null;
    _repCompleteMs = null;
    _descentDuration = null;
    _ascentDuration = null;
    _bottomHoldDuration = null;
    _descentAscentRatio = null;
    // Instructions survive reset — they carry coaching to next rep.
    // Cleared when new rep starts (standing → descending) in squat.dart.
  }
}
