import 'reverse_crunch_metric_base.dart';

class SwingingMomentumMetric extends ReverseCrunchMetricBase {
  @override
  String get name => 'SwingingMomentum';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _setupKneeAngle;
  double? _maxKneeDeviation;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.state == ReverseCrunchState.lying) {
      // Học góc gối lúc setup (khoảng 90 độ)
      _setupKneeAngle = ctx.kneeAngle;
      ctx.resultIssues.feedback['KneeLock'] = 'Khóa chặt gối';
      return;
    }

    if (_setupKneeAngle == null) return;

    // Tính độ lệch của góc gối so với lúc bắt đầu
    double deviation = (ctx.kneeAngle - _setupKneeAngle!).abs();
    if (_maxKneeDeviation == null || deviation > _maxKneeDeviation!) {
      _maxKneeDeviation = deviation;
    }

    _debugData['kneeDeviation'] = deviation.toStringAsFixed(1);
    _debugData['maxKneeDev'] = _maxKneeDeviation?.toStringAsFixed(1) ?? '-';

    if (deviation > ReverseCrunchConfig.KNEE_SWING_TOLERANCE) {
      ctx.resultIssues.feedback['KneeLock'] = 'Đang vung chân!';
    } else {
      ctx.resultIssues.feedback['KneeLock'] = 'Cố định tốt';
    }
  }

  @override
  void evaluateRepEnd(RepContext ctx) {
    if (_maxKneeDeviation != null && _maxKneeDeviation! > ReverseCrunchConfig.KNEE_SWING_TOLERANCE) {
      _faults.add(FaultRecord(
        phase: 'CURLING', type: 'Swinging', message: 'Dùng đà vung chân',
        affectsForm: true, priority: CrunchVoicePriority.momentum, 
        voiceMessage: 'Khóa chặt góc đầu gối! Đừng búng cẳng chân để lấy đà.'
      ));
      ctx.resultIssues.addInstruction('lying', 'KneeLock', 'Rep trước bạn vung chân lấy đà. Giữ cẳng chân cố định!');
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _maxKneeDeviation = null;
    // Không reset _setupKneeAngle để giữ chuẩn baseline
  }
}