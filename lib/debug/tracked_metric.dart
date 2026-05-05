import 'debug_types.dart';

class TrackedMetric {
  final DebugMetricSource metric;

  static const int maxHistory = 50;
  static const int maxTransitions = 12;

  final List<MetricSample> _history = [];
  final List<StatusTransition> _transitions = [];
  final Map<String, List<num>> _keyHistories = {};
  MetricStatus _lastStatus = MetricStatus.pass;

  TrackedMetric(this.metric);

  String get id => metric.name;
  double? get value => metric.value;
  MetricStatus get status => metric.status;
  ThresholdBand? get threshold => metric.threshold;
  List<MetricSample> get history => List.unmodifiable(_history);
  List<StatusTransition> get transitions => List.unmodifiable(_transitions);
  Map<String, List<num>> get keyHistories => Map.unmodifiable(
        _keyHistories.map(
          (key, value) => MapEntry(key, List<num>.unmodifiable(value)),
        ),
      );
  int get faultCount => _transitions
      .where((transition) => transition.to == MetricStatus.fault)
      .length;

  void onTick(int frameTimestampMs) {
    final v = metric.value;
    final st = metric.status;

    if (v != null) {
      _history.add(MetricSample(v, st));
      if (_history.length > maxHistory) _history.removeAt(0);
    }

    if (st != _lastStatus && v != null) {
      _transitions.add(StatusTransition(_lastStatus, st, v, frameTimestampMs));
      if (_transitions.length > maxTransitions) _transitions.removeAt(0);
      _lastStatus = st;
    }

    metric.debugData.forEach((key, val) {
      final numeric = _numericValue(val);
      if (numeric != null) {
        final list = _keyHistories.putIfAbsent(key, () => <num>[]);
        list.add(numeric);
        if (list.length > maxHistory) list.removeAt(0);
      }
    });
  }

  num? _numericValue(dynamic value) {
    if (value is num) return value;
    if (value is! String) return null;

    final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(value);
    if (match == null) return null;
    return num.tryParse(match.group(0)!);
  }

  void reset() {
    _history.clear();
    _transitions.clear();
    _keyHistories.clear();
    _lastStatus = MetricStatus.pass;
  }
}
