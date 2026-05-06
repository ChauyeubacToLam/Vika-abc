import 'sit_up_metric_base.dart';

class StabilityMetric extends SitUpMetricBase {
  @override
  String get name => 'LowerBodyStability';
  
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  double? _startAnkleY;

  @override
  List<FaultRecord> get faults => _faults;
  
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(SitUpState from, SitUpState to, int timestampMs) {
    if (to == SitUpState.rising) _startAnkleY = null;
  }

  @override
  void update(SitUpRepContext ctx) {
    if (ctx.state == SitUpState.lying) return;
         
    _startAnkleY ??= ctx.ankleY;
    if (ctx.scaleFactor != null) {
      double deviation = (ctx.ankleY - _startAnkleY!).abs() / ctx.scaleFactor!;
             
      if (deviation > 0.10 && !_faults.any((f) => f.type == 'Stability')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Stability',
          message: 'Bàn chân không giữ chặt',
          voiceMessage: 'Ép chặt chân xuống sàn nhà',
          affectsForm: true,
          priority: SitUpFaultPriority.heelLift,
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _startAnkleY = null;
  }
}