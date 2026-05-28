import 'reverse_crunch_metric_base.dart';

class PelvicCurlMetric extends ReverseCrunchMetricBase {
  @override
  String get name => 'PelvicCurl';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _baselineHipY;
  double? _baselineTrunkKneeAngle;
  double _minTrunkKneeAngle = 180.0;
  double _minHipY = 9999.0; // Y nhỏ nhất = Hông nâng cao nhất

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.state == ReverseCrunchState.lying) {
      _baselineHipY = ctx.hipY;
      _baselineTrunkKneeAngle = ctx.trunkKneeAngle;
      ctx.resultIssues.feedback['Curl'] = 'Sẵn sàng cuộn';
      return;
    }

    if (ctx.trunkKneeAngle < _minTrunkKneeAngle) _minTrunkKneeAngle = ctx.trunkKneeAngle;
    if (ctx.hipY < _minHipY) _minHipY = ctx.hipY;

    if (_baselineHipY != null && _baselineTrunkKneeAngle != null) {
      double angleDrop = _baselineTrunkKneeAngle! - ctx.trunkKneeAngle;
      double hipLiftNorm = (_baselineHipY! - ctx.hipY) / (ctx.scaleFactor == 0 ? 1 : ctx.scaleFactor);

      _debugData['angleDrop'] = angleDrop.toStringAsFixed(1);
      _debugData['hipLiftNorm'] = hipLiftNorm.toStringAsFixed(2);

      if (ctx.state == ReverseCrunchState.top) {
        if (angleDrop >= ReverseCrunchConfig.PELVIC_CURL_ANGLE_MIN_DROP && hipLiftNorm >= ReverseCrunchConfig.HIP_LIFT_MIN_NORMALIZED) {
          ctx.resultIssues.feedback['Curl'] = 'Cuộn rất sâu!';
        } else {
          ctx.resultIssues.feedback['Curl'] = 'Cuộn mông cao lên!';
        }
      } else if (ctx.state == ReverseCrunchState.curling) {
        ctx.resultIssues.feedback['Curl'] = 'Cuộn hông lên...';
      }
    }
  }

  @override
  void evaluateRepEnd(RepContext ctx) {
    if (_baselineHipY == null || _baselineTrunkKneeAngle == null) return;

    double maxAngleDrop = _baselineTrunkKneeAngle! - _minTrunkKneeAngle;
    double maxHipLift = (_baselineHipY! - _minHipY) / (ctx.scaleFactor == 0 ? 1 : ctx.scaleFactor);

    if (maxAngleDrop < ReverseCrunchConfig.PELVIC_CURL_ANGLE_MIN_DROP || maxHipLift < ReverseCrunchConfig.HIP_LIFT_MIN_NORMALIZED) {
      _faults.add(FaultRecord(
        phase: 'TOP', type: 'NoPelvicTilt', message: 'Hông không rời sàn',
        affectsForm: true, priority: CrunchVoicePriority.pelvicCurl, 
        voiceMessage: 'Bài tập vô nghĩa nếu hông không rời sàn. Hãy cuộn mông nhấc lên khỏi mặt đất!'
      ));
      ctx.resultIssues.addInstruction('lying', 'Curl', 'Cố gắng nhấc thắt lưng rời khỏi sàn nhé.');
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _minTrunkKneeAngle = 180.0;
    _minHipY = 9999.0;
    _baselineHipY = null;
    _baselineTrunkKneeAngle = null;
  }
}