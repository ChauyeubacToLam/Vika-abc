/* =========================================================================
   Metric 3: Descent Tempo Control
   Priority: 🟡 IMPORTANT — Joint safety + effectiveness
   
   Measures descent duration (plank → bottom).
   Detects uncontrolled free-fall dropping and bouncing.
   
   Architecture mirrors squat TempoMetric exactly:
   - onStateTransition() records timestamps + calculates durations
   - update() provides live feedback (null-gated)
   - evaluateRep() logs faults + sets coaching references
   
   Vietnamese context:
   - Beginners with weak upper body naturally descend slowly → GOOD
   - Do NOT penalize slow descents
   - Fast descents multiply impact loading on shoulders and wrists
   - Frame as "kiểm soát" (control) not strict timing
   ========================================================================= */

import 'push_up_metric_base.dart';
import '../push_up.dart';

class TempoConfig {
  /// Descent duration thresholds (seconds)
  static const double DESCENT_GOOD_MIN = 0.6;
  static const double DESCENT_WARNING_MIN = 0.3;
  // Below WARNING_MIN = error (free-fall)
}

class TempoMetric extends PushUpMetricBase {
  @override
  String get name => 'Tempo';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // --- Timestamps (milliseconds) ---
  int? _descentStartMs;
  int? _ascentStartMs;

  // --- Computed durations (seconds) ---
  double? _descentDuration;
  double? _ascentDuration;

  // --- Public getters ---
  double? get descentDuration => _descentDuration;
  double? get ascentDuration => _ascentDuration;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  /* -----------------------------------------------------------------------
     STATE TRANSITIONS — record timestamps + compute durations.
     ----------------------------------------------------------------------- */
  @override
  void onStateTransition(PushUpState from, PushUpState to, int timestampMs) {
    switch (to) {
      case PushUpState.descending:
        _descentStartMs = timestampMs;
        break;

      case PushUpState.bottom:
        if (_descentStartMs != null) {
          _descentDuration = (timestampMs - _descentStartMs!) / 1000.0;
          _debugData['descentDur'] =
              _descentDuration?.toStringAsFixed(2) ?? '-';
        }
        break;

      case PushUpState.ascending:
        _ascentStartMs = timestampMs;
        break;

      case PushUpState.plank:
        if (_ascentStartMs != null) {
          _ascentDuration = (timestampMs - _ascentStartMs!) / 1000.0;
          _debugData['ascentDur'] = _ascentDuration?.toStringAsFixed(2) ?? '-';
        }
        break;
    }
  }

  /* -----------------------------------------------------------------------
     PER-FRAME UPDATE — Live feedback (null-gated).
     ----------------------------------------------------------------------- */
  @override
  void update(RepContext ctx) {
    // Live check: descent speed (available after entering bottom)
    if (_descentDuration != null) {
      if (_descentDuration! < TempoConfig.DESCENT_WARNING_MIN) {
        ctx.resultIssues.feedback['Tempo'] = 'Không thả rơi! Kiểm soát cơ.';
      } else if (_descentDuration! < TempoConfig.DESCENT_GOOD_MIN) {
        ctx.resultIssues.feedback['Tempo'] = 'Hạ người chậm lại.';
      } else {
        ctx.resultIssues.feedback['Tempo'] = 'Tốc độ hạ người rất tốt!';
      }
    }
  }

  /* -----------------------------------------------------------------------
     REP COMPLETE — Log faults + preserve coaching references.
     Called by PushUp after rep completes.
     ----------------------------------------------------------------------- */
  void evaluateRep(RepContext ctx) {
    if (_descentDuration == null) {
      _debugData['tempoResult'] = 'no data';
      return;
    }

    const phase = 'REP_COMPLETE';

    if (_descentDuration! < TempoConfig.DESCENT_WARNING_MIN) {
      _logFault(phase,
          'Thả rơi quá nhanh (${_descentDuration!.toStringAsFixed(1)}s)');
      // Legacy UI instruction copy: Đừng thả rơi! Hạ người chậm 2-3 giây.
    } else if (_descentDuration! < TempoConfig.DESCENT_GOOD_MIN) {
      _logFault(
          phase, 'Hạ hơi nhanh (${_descentDuration!.toStringAsFixed(1)}s)');
      // Legacy UI instruction copy: Hạ người chậm hơn lần sau!
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
    _ascentStartMs = null;
    _descentDuration = null;
    _ascentDuration = null;
  }
}
