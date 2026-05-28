import 'dead_bug_metric_base.dart';
import '../../../utils/debouncer.dart';

class StableLimbsMetric extends DeadBugMetricBase {
  @override
  String get name => 'StableLimbs';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 3);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(DeadBugRepContext ctx) {
    if (ctx.state == DeadBugState.extending || ctx.state == DeadBugState.hold) {
      
      // Tìm chi ĐANG DUỖI (>125)
      bool lArmExt = ctx.leftArmAngle > 125.0;
      bool rArmExt = ctx.rightArmAngle > 125.0;
      bool lHipExt = ctx.leftHipAngle > 125.0;
      bool rHipExt = ctx.rightHipAngle > 125.0;

      bool anyExtending = lArmExt || rArmExt || lHipExt || rHipExt;
      if (!anyExtending) return;

      // Chi TRỤ (không duỗi) phải giữ ở mức < 115 độ
      bool lArmUnstable = !lArmExt && ctx.leftArmAngle > 115.0;
      bool rArmUnstable = !rArmExt && ctx.rightArmAngle > 115.0;
      bool lHipUnstable = !lHipExt && ctx.leftHipAngle > 115.0;
      bool rHipUnstable = !rHipExt && ctx.rightHipAngle > 115.0;

      if (_faultDebouncer.update(lArmUnstable || rArmUnstable || lHipUnstable || rHipUnstable)) {
         if (!_faults.any((f) => f.type == 'StableLimbs')) {
            _faults.add(FaultRecord(
              phase: ctx.state.name,
              type: 'StableLimbs',
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
    _faultDebouncer.reset();
  }
}