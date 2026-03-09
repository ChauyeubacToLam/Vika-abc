/* =========================================================================
   Metric 3: Tempo & Rhythm
   Priority: IMPORTANT — Ship Day 3
   
   Jumping jacks should maintain consistent rhythm. This metric tracks
   rep timing, detects fatigue (slowing down), and warns about rushing.
   
   Detection strategy:
   - Record timestamps at each state transition
   - repDuration = time from one CLOSED to next CLOSED
   - Track rhythm consistency via stdev of recent rep durations
   - Detect fatigue: last 3 reps >20% slower than first 5 rep average
   
   Thresholds:
     Good tempo:      0.8–1.5 seconds per rep
     Too slow:        > 2.0 seconds per rep
     Too fast:        < 0.5 seconds per rep (likely sloppy form)
   
     Consistent:      stdev of last 5 reps < 0.3s
     Inconsistent:    stdev > 0.5s
   
   Vietnamese context:
   - Office workers may fatigue quickly (sedentary lifestyle)
   - Encourage taking a break rather than pushing with bad form
   - Keep feedback motivating, not pressuring
   ========================================================================= */

import 'dart:math' as math;
import 'jumping_jack_metric_base.dart';
import '../jumping_jack.dart';

class TempoConfig {
  /// Good rep duration range (seconds)
  // ignore: constant_identifier_names
  static const double REP_MIN_GOOD = 0.8;
  // ignore: constant_identifier_names
  static const double REP_MAX_GOOD = 1.5;

  /// Too fast threshold — likely sloppy or miscounted
  // ignore: constant_identifier_names
  static const double REP_MIN_ERROR = 0.5;

  /// Too slow threshold — fatigue or hesitation
  // ignore: constant_identifier_names
  static const double REP_MAX_ERROR = 2.0;

  /// Rhythm consistency: stdev threshold for last N reps
  // ignore: constant_identifier_names
  static const double RHYTHM_GOOD_STDEV = 0.3;
  // ignore: constant_identifier_names
  static const double RHYTHM_BAD_STDEV = 0.5;

  /// Fatigue detection: percentage slower than baseline
  // ignore: constant_identifier_names
  static const double FATIGUE_THRESHOLD = 0.20; // 20% slower

  /// Number of initial reps to establish baseline
  // ignore: constant_identifier_names
  static const int BASELINE_REPS = 5;

  /// Number of recent reps to check for fatigue
  // ignore: constant_identifier_names
  static const int FATIGUE_CHECK_WINDOW = 3;

  /// Sliding window for rhythm consistency
  // ignore: constant_identifier_names
  static const int RHYTHM_WINDOW = 5;
}

class TempoMetric extends JJMetricBase {
  @override
  String get name => 'Tempo';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Timestamp tracking
  int? _lastClosedTimestamp;

  // Rep duration history (seconds)
  final List<double> _repDurations = [];

  // Current rep timing
  double? _currentRepDuration;

  /// Prevent instruction spam
  bool _tempoInstructionSet = false;
  bool _rhythmInstructionSet = false;
  bool _fatigueInstructionSet = false;

  /// Public accessors for post-rep logging
  double? get lastRepDuration => _currentRepDuration;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(JJState from, JJState to, int timestampMs) {}

  @override
  void update(RepContext ctx) {
    // Show current tempo info
    if (_repDurations.isNotEmpty) {
      final lastDur = _repDurations.last;
      _debugData['lastRepDur'] = '${lastDur.toStringAsFixed(2)}s';
    }
    _debugData['totalReps'] = _repDurations.length.toString();

    if (ctx.resultIssues.feedback['Tempo'] == null) {
      ctx.resultIssues.feedback['Tempo'] = 'Nhịp tốt!';
    }
  }

  /// Called by JumpingJack when a rep completes (OPEN → CLOSED).
  void evaluateRep(RepContext ctx, int repClosedTimestamp) {
    if (_lastClosedTimestamp == null) {
      _lastClosedTimestamp = repClosedTimestamp;
      _debugData['tempoResult'] = 'first rep (no data)';
      return;
    }

    _currentRepDuration = (repClosedTimestamp - _lastClosedTimestamp!) / 1000.0;

    // Filter out unreasonable durations (< 0.2s = glitch, > 5s = paused)
    if (_currentRepDuration! >= 0.2 && _currentRepDuration! <= 5.0) {
      _repDurations.add(_currentRepDuration!);
    }

    // Update timestamp for next rep
    _lastClosedTimestamp = repClosedTimestamp;

    if (_currentRepDuration == null) return;

    _debugData['repDuration'] = '${_currentRepDuration!.toStringAsFixed(2)}s';

    // --- 1. Rep speed check ---
    if (_currentRepDuration! < TempoConfig.REP_MIN_ERROR) {
      _logFault('REP_COMPLETE',
          'Quá nhanh (${_currentRepDuration!.toStringAsFixed(1)}s)');
      ctx.resultIssues.feedback['Tempo'] = 'Chậm lại, giữ form!';
      if (!_tempoInstructionSet) {
        ctx.resultIssues.addInstruction(
            'closed', 'Tempo speed', 'Chậm lại, giữ form chuẩn!');
        _tempoInstructionSet = true;
      }
    } else if (_currentRepDuration! > TempoConfig.REP_MAX_ERROR) {
      ctx.resultIssues.feedback['Tempo'] = 'Nhanh hơn một chút!';
      if (!_tempoInstructionSet) {
        ctx.resultIssues.addInstruction(
            'closed', 'Tempo speed', 'Cố gắng nhanh hơn lần sau!');
        _tempoInstructionSet = true;
      }
    } else if (_currentRepDuration! > TempoConfig.REP_MAX_GOOD) {
      ctx.resultIssues.feedback['Tempo'] = 'Nhanh hơn chút!';
    } else if (_currentRepDuration! < TempoConfig.REP_MIN_GOOD) {
      ctx.resultIssues.feedback['Tempo'] = 'Hơi nhanh!';
    } else {
      ctx.resultIssues.feedback['Tempo'] = 'Nhịp tốt!';
    }

    // --- 2. Rhythm consistency check (after enough reps) ---
    if (_repDurations.length >= TempoConfig.RHYTHM_WINDOW) {
      final recent = _repDurations
          .sublist(_repDurations.length - TempoConfig.RHYTHM_WINDOW);
      final stdev = _calculateStdev(recent);
      _debugData['rhythmStdev'] = stdev.toStringAsFixed(2);

      if (stdev > TempoConfig.RHYTHM_BAD_STDEV) {
        if (!_rhythmInstructionSet) {
          ctx.resultIssues
              .addInstruction('closed', 'Tempo rhythm', 'Giữ nhịp đều hơn!');
          _rhythmInstructionSet = true;
        }
      }
    }

    // --- 3. Fatigue detection ---
    if (_repDurations.length >=
        TempoConfig.BASELINE_REPS + TempoConfig.FATIGUE_CHECK_WINDOW) {
      final baseline = _repDurations.sublist(0, TempoConfig.BASELINE_REPS);
      final baselineAvg = baseline.reduce((a, b) => a + b) / baseline.length;

      final recentWindow = _repDurations
          .sublist(_repDurations.length - TempoConfig.FATIGUE_CHECK_WINDOW);
      final recentAvg =
          recentWindow.reduce((a, b) => a + b) / recentWindow.length;

      final slowdown = (recentAvg - baselineAvg) / baselineAvg;
      _debugData['fatigueSlowdown'] = '${(slowdown * 100).toStringAsFixed(0)}%';

      if (slowdown > TempoConfig.FATIGUE_THRESHOLD && !_fatigueInstructionSet) {
        ctx.resultIssues.addInstruction(
            'closed', 'Tempo fatigue', 'Bạn đang mệt — giữ nhịp hoặc nghỉ!');
        _fatigueInstructionSet = true;
      }
    }
  }

  double _calculateStdev(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean));
    return math.sqrt(squaredDiffs.reduce((a, b) => a + b) / values.length);
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'Tempo')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Tempo',
        message: message,
        affectsForm: false, // Tempo is informational for JJ
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _currentRepDuration = null;
    _tempoInstructionSet = false;
    _rhythmInstructionSet = false;
    // NOTE: Do NOT reset _repDurations, _lastClosedTimestamp, _fatigueInstructionSet
    // — these track across the entire set, not per-rep.
  }
}
