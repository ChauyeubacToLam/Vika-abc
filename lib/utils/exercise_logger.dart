/// Per-rep data snapshot logged at the end of each rep.
class RepLog {
  final bool correctForm;
  final int repNumber;
  final Map<String, dynamic> data;
  RepLog(
      {required this.repNumber, required this.data, required this.correctForm});
}

/// Collects per-rep logs and computes set-level aggregates.
///
/// Usage:
///   1. Call [addRepLog] after each rep with per-rep measurements.
///   2. On set completion, call aggregate helpers ([pushMax], [pushMin], etc.)
///      to summarize rep data into [setLogs].
///   3. Use [pushKey] for direct set-level values (e.g. total fault counts).
class ExerciseLogger {
  final List<RepLog> _repLogs = [];
  final Map<String, dynamic> _setLog = {};

  // --- Per-rep ---

  void addRepLog(RepLog repLog) => _repLogs.add(repLog);

  List<RepLog> get repLogs => List.unmodifiable(_repLogs);

  // --- Set-level: direct values ---

  /// Store a direct key-value pair in set logs (e.g. fault counts).
  void pushKey(String key, dynamic value) => _setLog[key] = value;

  // --- Set-level: aggregates across all reps ---

  void pushMax(String repKey, String label) =>
      _aggregate(repKey, label, (a, b) => a > b ? a : b);

  void pushMin(String repKey, String label) =>
      _aggregate(repKey, label, (a, b) => a < b ? a : b);

  void pushSum(String repKey, String label) =>
      _aggregate(repKey, label, (a, b) => a + b);

  void pushAverage(String repKey, String label) {
    final values = _numericValues(repKey);
    if (values.isEmpty) return;
    _setLog[label] = values.reduce((a, b) => a + b) / values.length;
  }

  void pushGoodRepCount() {
    _setLog['good_rep_count'] = repLogs.where((r) => r.correctForm).length;
  }

  // --- Output ---

  Map<String, dynamic> get setLogs => Map.unmodifiable(_setLog);

  void clear() {
    _repLogs.clear();
    _setLog.clear();
  }

  // --- Internal ---

  /// Extract all numeric values for [repKey] across reps.
  List<num> _numericValues(String repKey) =>
      _repLogs.map((r) => r.data[repKey]).whereType<num>().toList();

  /// Apply a reduce [fn] across all numeric values for [repKey].
  void _aggregate(String repKey, String label, num Function(num, num) fn) {
    final values = _numericValues(repKey);
    if (values.isEmpty) return;
    _setLog[label] = values.reduce(fn);
  }
}
