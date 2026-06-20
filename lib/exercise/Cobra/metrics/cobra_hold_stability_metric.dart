// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:math' as math;
import 'cobra_metric_base.dart';
import '../cobra.dart';

/// MET-6: Hold Stability and Duration (Quality Metric)
/// Meta-metric that aggregates data over the hold window.
/// Post-set summary only — NEVER triggers real-time alert.
/// Measures holdDuration, angleDriftSD, and trendScore.
class CobraHoldStabilityMetric extends CobraMetricBase {
  @override
  String get name => 'HoldStability';

  // Beginner thresholds
  static const double _goodDurationMin = 2.0; // seconds
  static const double _goodDriftMax = 12.0; // degrees SD
  static const double _warningDriftMax = 18.0;

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Tracking data during hold
  final List<double> _trunkAngles = [];
  int? _holdStartMs;
  double _holdDuration = 0.0;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.state != CobraState.holding) return;

    _trunkAngles.add(ctx.trunkDeviation);

    if (_holdStartMs != null) {
      _holdDuration = (ctx.frameTimestampMs - _holdStartMs!) / 1000.0;
    }

    _debugData['holdDur'] = _holdDuration.toStringAsFixed(1);

    // Compute running SD if enough samples
    if (_trunkAngles.length >= 10) {
      final sd = _computeSD(_trunkAngles);
      _debugData['holdSD'] = sd.toStringAsFixed(1);
    }
  }

  @override
  void onStateTransition(CobraState from, CobraState to, int timestampMs) {
    if (to == CobraState.holding) {
      _holdStartMs = timestampMs;
      _trunkAngles.clear();
      _holdDuration = 0.0;
    }

    // When hold ends → compute summary
    if (from == CobraState.holding && to != CobraState.holding) {
      _computeHoldSummary();
    }
  }

  void _computeHoldSummary() {
    if (_trunkAngles.length < 5) return;

    final sd = _computeSD(_trunkAngles);

    _debugData['finalHoldDur'] = _holdDuration.toStringAsFixed(1);
    _debugData['finalHoldSD'] = sd.toStringAsFixed(1);

    // Quality assessment (post-rep, NOT real-time)
    if (_holdDuration >= _goodDurationMin && sd <= _goodDriftMax) {
      // Good hold — no fault, just positive feedback
      _debugData['holdQuality'] = 'good';
    } else if (sd > _warningDriftMax) {
      _faults.add(FaultRecord(
        phase: 'summary',
        type: 'UnstableHold',
        message: 'Giữ tư thế chưa ổn định (SD=${sd.toStringAsFixed(1)}°)',
        affectsForm: false, // does NOT affect form score
      ));
      _debugData['holdQuality'] = 'unstable';
    } else {
      _debugData['holdQuality'] = 'ok';
    }
  }

  double _computeSD(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _trunkAngles.clear();
    _holdStartMs = null;
    _holdDuration = 0.0;
  }
}
