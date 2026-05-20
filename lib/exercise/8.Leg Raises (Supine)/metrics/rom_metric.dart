import 'leg_raise_metric_base.dart';

class RomMetric extends LegRaiseMetricBase {
  @override
  String get name => 'ROM';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  double? minHipFlexion;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LegRaiseRepContext ctx) {
    if (ctx.state == LegRaiseState.raising || ctx.state == LegRaiseState.top) {
      if (minHipFlexion == null || ctx.hipFlexionAngle < minHipFlexion!) {
        minHipFlexion = ctx.hipFlexionAngle;
      }
    }
  }

  void evaluateRep(LegRaiseRepContext ctx) {
    // Góc vai-hông-gối lúc cao nhất phải đạt ít nhất 100 độ (lên đủ 90 là đẹp nhất)
    if (minHipFlexion == null || minHipFlexion! > 100.0) {
       _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'ROM',
          message: minHipFlexion == null
              ? 'Lên chưa đủ cao (Không nhận diện được pha nâng chân)'
              : 'Lên chưa đủ cao (Góc đỉnh: ${minHipFlexion!.toStringAsFixed(1)}°)',
          voiceMessage: 'Nâng chân lên vuông góc với trần nhà',
          affectsForm: true,
          priority: LegRaiseFaultPriority.rom,
        ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    minHipFlexion = null;
  }
}