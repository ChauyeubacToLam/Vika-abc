/// Continuous hold-time integrator for hold-based exercises (plank, cobra,
/// warrior, etc.).
///
/// Unlike [ExerciseLogger] (which snapshots discrete rep events and aggregates
/// them lazily at set-end), this integrates *wall-clock time* frame by frame
/// while the user holds a pose, bucketing seconds into a good-hold total plus
/// one accumulator per fault key.
///
/// Two behaviors make it its own concept:
/// - `dt`-gating: inter-frame deltas outside [minFrameDeltaMs, maxFrameDeltaMs]
///   are dropped, so paused/dropped/janky frames never inflate the hold time.
/// - interruption handling: [resetTick] clears the last tick so the gap between
///   "left the pose" and "came back" is not counted as held time.
///
/// At set-end the exercise pushes these totals into [ExerciseLogger] via
/// `pushKey('good_seconds', ...)` etc. — this class feeds the logger, it does
/// not replace it.
class HoldSecondsAccumulator {
  HoldSecondsAccumulator(Iterable<String> faultKeys) {
    for (final key in faultKeys) {
      _faultSeconds[key] = 0.0;
    }
  }

  static const int minFrameDeltaMs = 10;
  static const int maxFrameDeltaMs = 250;

  final Map<String, double> _faultSeconds = {};
  double _goodSeconds = 0.0;
  int? _lastHoldTickMs;

  double get goodSeconds => _goodSeconds;

  double faultSecondsFor(String key) => _faultSeconds[key] ?? 0.0;

  void reset() {
    _goodSeconds = 0.0;
    for (final key in _faultSeconds.keys) {
      _faultSeconds[key] = 0.0;
    }
    _lastHoldTickMs = null;
  }

  void resetTick() {
    _lastHoldTickMs = null;
  }

  void accumulate({
    required int elapsedMs,
    required Map<String, bool> faultingByKey,
    Iterable<String>? goodBlockingKeys,
  }) {
    for (final key in faultingByKey.keys) {
      _faultSeconds.putIfAbsent(key, () => 0.0);
    }

    final previous = _lastHoldTickMs;
    _lastHoldTickMs = elapsedMs;
    if (previous == null) return;

    final dtMs = elapsedMs - previous;
    if (dtMs < minFrameDeltaMs || dtMs > maxFrameDeltaMs) return;

    final seconds = dtMs / 1000.0;
    var hasFault = false;
    final goodBlockingSet = goodBlockingKeys?.toSet();
    var hasGoodBlockingFault = false;
    for (final entry in faultingByKey.entries) {
      if (!entry.value) continue;
      hasFault = true;
      if (goodBlockingSet == null || goodBlockingSet.contains(entry.key)) {
        hasGoodBlockingFault = true;
      }
      _faultSeconds[entry.key] = (_faultSeconds[entry.key] ?? 0.0) + seconds;
    }

    if (!hasFault || !hasGoodBlockingFault) {
      _goodSeconds += seconds;
    }
  }
}
