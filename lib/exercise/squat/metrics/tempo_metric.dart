/* =========================================================================
   Metric 4: Descent Tempo Control
   Priority: NICE-TO-HAVE — Ship Month 1-2
   
   Measures time for descent vs ascent phase.
   Detects:
   - Uncontrolled dropping (no eccentric control)
   - Bouncing out of the bottom (no pause)
   - Slow grinding ascent (struggling / weak quads)
   
   APPROACH:
   - onStateTransition() records timestamps at each phase change.
   - evaluateRep() runs post-rep to calculate durations and log faults.
   - update() shows reminders from PREVIOUS rep during CURRENT rep.
   
   FEEDBACK TIMING ("coach next rep" pattern):
   The reminder shows ONE PHASE BEFORE the user needs it:
     Descent too fast  → remind during Standing    (before they go down)
     Bottom too short  → remind during Descending  (before they reach bottom)
     Ascent too slow   → remind during Bottom      (before they push up)
   
   Vietnamese Adjustments (Weeks 1-4):
   - Beginners with stiff ankles often descend slowly (3-5s) → ACCEPTABLE
   - Good descent: 2-5s (beginner), tightens to 2-3.5s at Month 4+
   - Frame as "rhythm" not strict timing
   ========================================================================= */

import 'squat_metric_base.dart';
import '../squat.dart';

class TempoConfig {
  /* --- Descent Duration (seconds) --- */
  static const double DESCENT_MIN_GOOD = 0.4; // Below this = a bit fast
  static const double DESCENT_MAX_GOOD = 2.0; // Above this = slow
  static const double DESCENT_MIN_ERROR =
      0.25; // Below this = dropped like a rock (no control)

  /* --- Bottom Hold (seconds) --- */
  /// Below this = bouncing (no controlled pause at bottom).
  static const double BOTTOM_HOLD_MIN = 0.8;

  /* --- Descent:Ascent Ratio --- */
  static const double RATIO_GOOD = 1.0;
  static const double RATIO_WARNING = 0.5;

  /* --- Ascent Struggle Detection --- */
  /// If ascent > descent × this multiplier, user is struggling.
  /// Not a form error — coaching observation for weak quads.
  static const double ASCENT_STRUGGLE_MULTIPLIER = 2.0;
}

/* =========================================================================
   Cross-rep coaching issues.
   Each field is null (no issue) or a feedback message string.
   Survives reset() — cleared at start of next evaluateRep().
   ========================================================================= */
class _TempoIssues {
  String? descentIssue; // Shown during Standing  (before descent)
  String? bottomIssue; // Shown during Descending (before bottom)
  String? ascentIssue; // Shown during Bottom     (before ascent)

  bool get hasAny =>
      descentIssue != null || bottomIssue != null || ascentIssue != null;
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

  // --- Cross-rep coaching (survives reset) ---
  final _TempoIssues _nextRepIssues = _TempoIssues();

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
     STATE TRANSITIONS
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
          _debugData['ascendingTime'] =
              _ascentStartMs?.toStringAsFixed(2) ?? '-';
          _debugData['standingTime'] = timestampMs.toStringAsFixed(2);

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
     PER-FRAME UPDATE — Show reminder from PREVIOUS rep.
     Each reminder appears one phase before the user needs it.
      Descent too fast  → remind during Standing    (before they go down)
      Bottom too short  → remind during Descending  (before they reach bottom)
      Ascent too slow   → remind during Bottom      (before they push up)
     ----------------------------------------------------------------------- */
  @override
  Map<String, String> update(RepContext ctx) {
    final feedback = <String, String>{};
    if (!_nextRepIssues.hasAny) return feedback;

    switch (ctx.squatState) {
      case SquatState.standing:
        _nextRepIssues.ascentIssue = null;

        break;

      case SquatState.descending:
        if (_nextRepIssues.bottomIssue != null) {
          feedback['Tempo'] = _nextRepIssues.bottomIssue!;
        }
        break;

      case SquatState.bottom:
        _nextRepIssues.descentIssue = null;
        if (_nextRepIssues.ascentIssue != null) {
          feedback['Tempo'] = _nextRepIssues.ascentIssue!;
        }
        break;

      case SquatState.ascending:
        // No reminder during ascent — they're already doing it
        _nextRepIssues.bottomIssue = null;

        break;
    }

    _debugData['nextIssues'] = {
      'descent': _nextRepIssues.descentIssue?.toString() ?? '-',
      'bottom': _nextRepIssues.bottomIssue?.toString() ?? '-',
      'ascent': _nextRepIssues.ascentIssue?.toString() ?? '-',
    };
    return feedback;
  }

  /* -----------------------------------------------------------------------
     REP COMPLETE — Evaluate this rep, set coaching flags for next rep.
     ----------------------------------------------------------------------- */
  void evaluateRep() {
    // Clear previous issues — fresh evaluation from this rep

    if (_descentDuration == null) {
      _debugData['tempoResult'] = 'no data';
      return;
    }

    final phase = 'REP_COMPLETE';

    // --- 1. Descent duration ---
    if (_descentDuration! < TempoConfig.DESCENT_MIN_ERROR) {
      _logFault(
          phase, 'Dropped too fast (${_descentDuration!.toStringAsFixed(1)}s)');
      _nextRepIssues.descentIssue =
          'Drop too fast last rep, go down slower this time';
    } else if (_descentDuration! < TempoConfig.DESCENT_MIN_GOOD) {
      _logFault(phase,
          'Descent a bit fast (${_descentDuration!.toStringAsFixed(1)}s)');
      _nextRepIssues.descentIssue =
          'Drop a bit faster last rep, try 2-3 seconds on the way down';
    }

    // --- 2. Bottom hold (bounce detection) ---
    if (_bottomHoldDuration != null &&
        _bottomHoldDuration! < TempoConfig.BOTTOM_HOLD_MIN) {
      _logFault(phase,
          'Bounced at bottom (${_bottomHoldDuration!.toStringAsFixed(2)}s hold)');
      _nextRepIssues.bottomIssue =
          'Last time not holding at the bottom, pause this time!';
    }

    // --- 3. Descent:Ascent ratio (eccentric control) ---
    // Low ratio = descent much faster than ascent = no control going down.
    // We only flag low ratio. High ratio (fast ascent) is GOOD — explosive.
    if (_descentAscentRatio != null) {
      if (_descentAscentRatio! < TempoConfig.RATIO_WARNING) {
        _logFault(phase,
            'No eccentric control (ratio ${_descentAscentRatio!.toStringAsFixed(1)})');
        // Only set if descent wasn't already flagged (avoid double-nagging)
        _nextRepIssues.ascentIssue ??=
            'No eccentric control last time,Control the way down';
      } else if (_descentAscentRatio! >
          TempoConfig.RATIO_GOOD + TempoConfig.RATIO_WARNING) {
        _logFault(phase,
            'Ascent too fast compared to descent (ratio ${_descentAscentRatio!.toStringAsFixed(1)})');
        _nextRepIssues.ascentIssue =
            'Ascent too fast last time, drive up slowly with control';
      }
    }

    // --- 4. Ascent struggle detection ---
    // If ascent takes >2× descent time, they're grinding.
    // This is a coaching observation, NOT a form fault.
    // Hints at weak quads — useful for programming recommendations.
    if (_descentDuration != null &&
        _ascentDuration != null &&
        _ascentDuration! >
            _descentDuration! * TempoConfig.ASCENT_STRUGGLE_MULTIPLIER) {
      _nextRepIssues.ascentIssue = 'Drive up with more power!';
      // Intentionally NOT logged as fault — coaching only
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
    // _nextRepIssues is NOT reset here — carries to next rep.
    // get cleared in update().
  }
}
