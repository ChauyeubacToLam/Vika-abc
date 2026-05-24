/* =========================================================================
   Metric 3: Trunk Alignment on Landing (Trục thân khi tiếp đất)
   Priority: 🟠 HIGH — Chấn thương cột sống (Lỗi bù trừ)
   
   Khi tiếp đất, phản xạ tự nhiên của người lưng yếu là rạp úp người về trước
   thay vì trùng gối gánh tạ. Góc nghiêng lưng > 45 độ là nguy hiểm.
   ========================================================================= */

import 'jump_squat_metric_base.dart';

class TrunkLandingConfig {
  static const double MAX_LEAN_ANGLE = 45.0; // Rạp quá 45 độ so với trục dọc
}

class LandingTrunkAlignmentMetric extends JumpSquatMetricBase {
  @override
  String get name => 'TrunkLanding';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _maxLeanAngle;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    // Theo dõi lưng lúc tiếp đất (moment có gia tốc lớn nhất dội vào cột sống)
    if (ctx.jumpSquatState == JumpSquatState.landing) {
      if (_maxLeanAngle == null || ctx.trunkVerticalAngle > _maxLeanAngle!) {
        _maxLeanAngle = ctx.trunkVerticalAngle;
      }
      _debugData['maxLean'] = _maxLeanAngle?.toStringAsFixed(1) ?? '-';
      
      // Live feedback nếu đang rạp lưng
      if (ctx.trunkVerticalAngle > TrunkLandingConfig.MAX_LEAN_ANGLE) {
        ctx.resultIssues.feedback['Back'] = 'Cảnh báo: Rạp lưng khi tiếp đất!';
      }
    }
  }

  @override
  void onStateTransition(JumpSquatState from, JumpSquatState to, int timestampMs) {
    if (from == JumpSquatState.landing && to == JumpSquatState.standing) {
      if (_maxLeanAngle != null && _maxLeanAngle! > TrunkLandingConfig.MAX_LEAN_ANGLE) {
        _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'Back',
          message: 'Lưng rạp úp quá mức khi tiếp đất (${_maxLeanAngle!.toStringAsFixed(0)}°)! Giữ ngực cao.',
          voiceMessage: 'Giữ thẳng lưng',
          affectsForm: true,
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _maxLeanAngle = null;
  }
}