import 'high_plank_metric_base.dart';
import '../high_plank.dart';

class ElbowMetric extends HighPlankMetricBase {
  @override
  String get name => 'BentElbows';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  bool _isFaulting = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(HighPlankRepContext ctx) {
    // FIX Bug 4: Chỉ ghi fault khi đang HOLDING.
    // Trong SETUP user đang vào vị trí, tay chưa lock — không nên bị tính lỗi.
    if (ctx.state != HighPlankState.holding) {
      _isFaulting = false;
      return;
    }

    // FIX Bug 3: Dùng HOLDING_ARM_THRESHOLD (160°) thay vì DROPPING_ARM_ANGLE (150°).
    // Spec yêu cầu arm phải luôn >= 160° khi holding. Dải 150–160° là hysteresis của
    // state machine (tránh rung state) nhưng user vẫn cần được cảnh báo trong vùng đó.
    // Nếu dùng 150°, user có thể ở HOLDING với arm 155° mà không nhận được feedback nào.
    if (ctx.shoulderElbowWristAngle < HighPlankConfig.HOLDING_ARM_THRESHOLD) {
      if (!_isFaulting) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'BentElbow',
          message: 'Khuỷu tay bị gập',
          voiceMessage: 'Duỗi thẳng cánh tay ra',
          affectsForm: true,
          priority: HighPlankFaultPriority.bentElbows,
        ));
        _isFaulting = true;
      }
    } else {
      _isFaulting = false;
    }
  }

  @override
  void reset() {}
}
