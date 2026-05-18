import 'mountain_climber_metric_base.dart';

class KneeDriveRomMetric extends ClimberMetricBase {
  @override
  String get name => 'KneeDriveROM';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  double? _minKneeToShoulderDist; // Tìm khoảng cách X ngắn nhất (gần ngực nhất)

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    // Tính khoảng cách X tương đối
    double dist = (ctx.activeKneeX - ctx.shoulderX).abs() / (ctx.scaleFactor == 0 ? 1 : ctx.scaleFactor);
    
    if (_minKneeToShoulderDist == null || dist < _minKneeToShoulderDist!) {
      _minKneeToShoulderDist = dist;
    }
    
    _debugData['kneeDistanceNorm'] = dist.toStringAsFixed(2);
    _debugData['minKneeDistance'] = _minKneeToShoulderDist?.toStringAsFixed(2) ?? '-';

    if (ctx.state == ClimberState.max_flexion) {
      // Giả sử khoảng cách lý tưởng là < 0.6 thân người (vượt qua hông)
      if (dist > 0.6) {
        ctx.resultIssues.feedback['ROM'] = 'Kéo gối cao lên!';
      } else {
        ctx.resultIssues.feedback['ROM'] = 'Biên độ tốt';
      }
    }
  }

  void evaluateRepEnd(RepContext ctx) {
    if (_minKneeToShoulderDist != null && _minKneeToShoulderDist! > 0.6) {
      _faults.add(FaultRecord(
        phase: 'MAX_FLEXION', type: 'ShortROM', message: 'Co gối quá ngắn',
        affectsForm: true, priority: ClimberVoicePriority.kneeRom, voiceMessage: 'Co gối sâu hơn về phía ngực'
      ));
      ctx.resultIssues.addInstruction('high_plank_base', 'ROM', 'Co gối sâu hơn ở nhịp sau');
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _minKneeToShoulderDist = null;
  }
}