import 'sit_up_metric_base.dart';

class RomMetric extends SitUpMetricBase {
  @override
  String get name => 'ROM';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  double? minKneeHipShoulder;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SitUpRepContext ctx) {
    if (ctx.state == SitUpState.rising || ctx.state == SitUpState.upright) {
      if (minKneeHipShoulder == null ||
          ctx.kneeHipShoulderAngle < minKneeHipShoulder!) {
        minKneeHipShoulder = ctx.kneeHipShoulderAngle;
      }
    }
  }

  // FIX: Bỏ param ctx — hàm chỉ dùng minKneeHipShoulder đã được tích lũy qua update()
  void evaluateRep() {
    if (minKneeHipShoulder != null && minKneeHipShoulder! > 100.0) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'ROM',
        message:
            'Chưa lên cao nhất: ${minKneeHipShoulder!.toStringAsFixed(1)} độ',
        voiceMessage: 'Cố gắng cuộn người cao hơn nữa',
        affectsForm: true,
        priority: SitUpFaultPriority.rom,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    minKneeHipShoulder = null;
  }
}
