import 'v_up_metric_base.dart';

class VShapeRomMetric extends VUpMetricBase {
  @override
  String get name => 'VShapeROM';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  double? minVAngle;
  double? minWristAnkleDist;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(VUpRepContext ctx) {
    if (ctx.state == VUpState.rising || ctx.state == VUpState.v_position) {
      if (minVAngle == null || ctx.shoulderHipAnkleAngle < minVAngle!) {
        minVAngle = ctx.shoulderHipAnkleAngle;
      }
      if (minWristAnkleDist == null || ctx.wristAnkleDistance < minWristAnkleDist!) {
        minWristAnkleDist = ctx.wristAnkleDistance;
      }
    }
  }

  void evaluateRep(VUpRepContext ctx) {
    // Góc phải khép lại <= 80 độ mới tính là đạt
    if (minVAngle != null && minVAngle! > 80.0) {
       _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'ROM',
          message: 'Chưa gập đủ sâu (Góc nhỏ nhất: ${minVAngle!.toStringAsFixed(1)}°)',
          voiceMessage: 'Cố gắng rướn tay chạm vào mũi chân nhé',
          affectsForm: true,
          priority: VUpFaultPriority.rom,
        ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    minVAngle = null;
    minWristAnkleDist = null;
  }
}