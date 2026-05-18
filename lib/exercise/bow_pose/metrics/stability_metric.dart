import 'dart:math' as math;
import 'bow_pose_metric_base.dart';

class StabilityMetric extends BowPoseMetricBase {
  @override
  String get name => 'Stability';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  final List<double> _shoulderYHistory = [];

  @override
  List<FaultRecord> get faults => _faults;
  
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.bowPoseState == BowPoseState.hold) {
      _shoulderYHistory.add(ctx.rawShoulderY / ctx.referenceLength);
    }
  }

  @override
  void evaluateRep(RepContext ctx) {
    if (_shoulderYHistory.length < 10) {
      ctx.resultIssues.feedback['StabilityScore'] = 'N/A';
      return;
    }

    double mean = _shoulderYHistory.reduce((a, b) => a + b) / _shoulderYHistory.length;
    
    double variance = _shoulderYHistory
        .map((y) => math.pow(y - mean, 2))
        .reduce((a, b) => a + b) / _shoulderYHistory.length;
    
    double stdDev = math.sqrt(variance);

    // StdDev 0.05 (5% body length) = 0 điểm. Càng tĩnh điểm càng cao.
    double scoreFactor = 1.0 - (stdDev / 0.05);
    int score = (scoreFactor * 100).clamp(0, 100).toInt();

    _debugData['stabilityScore'] = '$score%';
    ctx.resultIssues.feedback['StabilityScore'] = '$score%';
    
    if (score < 50) {
       _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'Stability',
        message: 'Tư thế bị rung lắc nhiều (Score: $score%)',
        affectsForm: false, 
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _shoulderYHistory.clear();
  }
}