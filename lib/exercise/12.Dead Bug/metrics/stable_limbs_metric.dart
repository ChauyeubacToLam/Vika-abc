import 'dead_bug_metric_base.dart';
import '../../../utils/debouncer.dart';

class StableLimbsMetric extends DeadBugMetricBase {
  @override
  String get name => 'StableLimbs';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 5);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _debugData['supportMaxAngle'] as double?;

  @override
  ThresholdBand? get threshold => const ThresholdBand(faultAbove: 135.0);

  @override
  void update(DeadBugRepContext ctx) {
    if (ctx.state == DeadBugState.extending || ctx.state == DeadBugState.hold) {
      // Tìm chi ĐANG DUỖI (>125)
      bool lArmExt = ctx.leftArmAngle > 118.0;
      bool rArmExt = ctx.rightArmAngle > 118.0;
      bool lHipExt = ctx.leftHipAngle > 118.0;
      bool rHipExt = ctx.rightHipAngle > 118.0;

      bool anyExtending = lArmExt || rArmExt || lHipExt || rHipExt;
      if (!anyExtending) return;

      // Chi TRỤ (không duỗi) phải giữ ở mức < 115 độ
      bool lArmUnstable = !lArmExt && ctx.leftArmAngle > 135.0;
      bool rArmUnstable = !rArmExt && ctx.rightArmAngle > 135.0;
      bool lHipUnstable = !lHipExt && ctx.leftHipAngle > 135.0;
      bool rHipUnstable = !rHipExt && ctx.rightHipAngle > 135.0;
      final supportAngles = <double>[
        if (!lArmExt) ctx.leftArmAngle,
        if (!rArmExt) ctx.rightArmAngle,
        if (!lHipExt) ctx.leftHipAngle,
        if (!rHipExt) ctx.rightHipAngle,
      ];
      _debugData['supportMaxAngle'] = supportAngles.isEmpty
          ? 0.0
          : supportAngles.reduce((a, b) => a > b ? a : b);

      if (_faultDebouncer.update(
          lArmUnstable || rArmUnstable || lHipUnstable || rHipUnstable)) {
        if (!_faults.any((f) => f.type == 'stable_limbs')) {
          _faults.add(FaultRecord(
            phase: ctx.state.name,
            type: 'stable_limbs',
            message: 'Chi trụ bị kéo xê dịch',
            voiceMessage: 'Giữ cố định tay và chân còn lại vuông góc nhé!',
            affectsForm: true,
            priority: DeadBugFaultPriority.stableLimbs,
          ));
        }
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _faultDebouncer.reset();
  }
}
