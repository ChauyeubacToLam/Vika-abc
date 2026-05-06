import 'lying_leg_raise_metric_base.dart';

class VerticalLegRomMetric extends LyingLegRaiseMetricBase {
  @override
  String get name => 'VerticalLegROM';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double _peakLegAngle = 0.0;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.legHorizontalAngle > _peakLegAngle) {
      _peakLegAngle = ctx.legHorizontalAngle;
    }
    
    _debugData['legAngle'] = ctx.legHorizontalAngle.toStringAsFixed(1);
    _debugData['peakLegAngle'] = _peakLegAngle.toStringAsFixed(1);

    if (ctx.state == LyingLegRaiseState.top) {
      if (ctx.legHorizontalAngle >= LegRaiseConfig.TOP_ANGLE_MIN_GOOD) {
        ctx.resultIssues.feedback['ROM'] = 'Chân dựng đứng rất tốt';
      } else {
        ctx.resultIssues.feedback['ROM'] = 'Nâng cao vuông góc sàn!';
      }
    }
  }

  @override
  void evaluateRepEnd(RepContext ctx) {
    if (_peakLegAngle < LegRaiseConfig.TOP_ANGLE_ERROR) {
      _faults.add(FaultRecord(
        phase: 'TOP', type: 'ShortROM', message: 'Biên độ quá ngắn',
        affectsForm: true, priority: LegRaiseVoicePriority.rom, 
        voiceMessage: 'Hãy nâng gót chân cao lên vuông góc với trần nhà.'
      ));
      ctx.resultIssues.addInstruction('lying', 'ROM', 'Rep vừa rồi nâng chưa đủ cao.');
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _peakLegAngle = 0.0;
  }
}