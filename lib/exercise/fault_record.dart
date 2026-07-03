import '../debug/debug_types.dart';

class FaultRecord {
  final String phase;
  final String type;
  final String message;
  final bool affectsForm;
  final String? voiceMessage;
  final int priority; // lower = higher priority

  FaultRecord({
    required this.phase,
    required this.type,
    required this.message,
    this.affectsForm = true,
    this.voiceMessage,
    this.priority = 99,
  });
}

mixin FaultMetricDebugSource {
  String get name;
  List<FaultRecord> get faults;
  Map<String, dynamic> get debugData;
  double? get value {
    for (final entryValue in debugData.values) {
      if (entryValue is num) return entryValue.toDouble();
      if (entryValue is String) {
        final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(entryValue);
        if (match != null) return double.tryParse(match.group(0)!);
      }
    }
    return null;
  }

  ThresholdBand? get threshold => null;
  MetricStatus get status {
    if (faults.any((fault) => fault.affectsForm)) {
      return MetricStatus.fault;
    }
    if (faults.isNotEmpty) return MetricStatus.near;
    return MetricStatus.pass;
  }
}
