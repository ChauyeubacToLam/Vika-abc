import 'reverse_crunch_metric_base.dart';

class PelvicCurlMetric extends ReverseCrunchMetricBase {
  @override
  String get name => 'PelvicCurl';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _baselineTrunkKneeAngle;
  double _minTrunkKneeAngle = 180.0;
  double _maxHipLift = 0.0;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.state == ReverseCrunchState.lying) {
      _baselineTrunkKneeAngle ??= ctx.trunkKneeAngle;
      ctx.resultIssues.feedback['Curl'] = 'Sẵn sàng cuộn';
      return;
    }

    if (ctx.trunkKneeAngle < _minTrunkKneeAngle) {
      _minTrunkKneeAngle = ctx.trunkKneeAngle;
    }
    if (ctx.hipLiftNormalized > _maxHipLift) {
      _maxHipLift = ctx.hipLiftNormalized;
    }

    final angleDrop = _baselineTrunkKneeAngle == null
        ? 0.0
        : _baselineTrunkKneeAngle! - ctx.trunkKneeAngle;

    _debugData['angleDrop'] = angleDrop.toStringAsFixed(1);
    _debugData['hipLiftNorm'] = ctx.hipLiftNormalized.toStringAsFixed(2);
    _debugData['maxHipLift'] = _maxHipLift.toStringAsFixed(2);

    if (ctx.state == ReverseCrunchState.top) {
      ctx.resultIssues.feedback['Curl'] = 'Cuộn hông tốt';
    } else if (ctx.state == ReverseCrunchState.curling) {
      ctx.resultIssues.feedback['Curl'] = 'Cuộn gối về ngực';
    } else if (ctx.state == ReverseCrunchState.lowering) {
      ctx.resultIssues.feedback['Curl'] = 'Hạ về góc 90 độ';
    }
  }

  @override
  void evaluateRepEnd(RepContext ctx) {
    if (_baselineTrunkKneeAngle == null) return;

    final maxAngleDrop = _baselineTrunkKneeAngle! - _minTrunkKneeAngle;

    if (maxAngleDrop < ReverseCrunchConfig.PELVIC_CURL_ANGLE_MIN_DROP ||
        _maxHipLift < ReverseCrunchConfig.HIP_LIFT_MIN_NORMALIZED) {
      _faults.add(FaultRecord(
        phase: 'TOP',
        type: 'NoPelvicTilt',
        message: 'Hông chưa nhấc khỏi sàn',
        affectsForm: true,
        priority: CrunchVoicePriority.pelvicCurl,
        voiceMessage: 'Co gối về ngực và cuộn hông nhấc lên khỏi thảm.',
      ));
      ctx.resultIssues.addInstruction(
        'lying',
        'Curl',
        'Co gối về ngực trước, rồi cuộn xương chậu lên khỏi thảm.',
      );
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _minTrunkKneeAngle = 180.0;
    _maxHipLift = 0.0;
    _baselineTrunkKneeAngle = null;
  }
}
