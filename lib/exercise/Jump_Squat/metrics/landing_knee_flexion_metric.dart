/* =========================================================================
   Metric 1: Landing Knee Flexion (Gập gối tiếp đất)
   Priority: 🔴 CRITICAL — Lỗi chí mạng phá hủy khớp gối
   
   Medical Theory (Hewett, 2005): 
   - Tiếp đất chân thẳng (góc > 90) đẩy 100% lực dội Ground Reaction Force 
     vào sụn chêm và dây chằng chéo trước (ACL).
   - Phải gập gối xuống <= 60 độ để cơ đùi (Quads/Glutes) hấp thụ lực.
   ========================================================================= */

import 'jump_squat_metric_base.dart';

class LandingConfig {
  static const double SAFE_FLEXION_MAX = 60.0;
  static const double STIFF_LANDING_MIN = 90.0; // CRITICAL ERROR
}

class LandingKneeFlexionMetric extends JumpSquatMetricBase {
  @override
  String get name => 'LandingFlexion';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _minLandingKneeAngle;
  bool _evaluated = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    // Chỉ tracking tìm góc gối sâu nhất trong pha LANDING
    if (ctx.jumpSquatState == JumpSquatState.landing) {
      if (_minLandingKneeAngle == null ||
          ctx.kneeAngle < _minLandingKneeAngle!) {
        _minLandingKneeAngle = ctx.kneeAngle;
      }
      _debugData['minLandingKnee'] =
          _minLandingKneeAngle?.toStringAsFixed(1) ?? '-';
    }
  }

  @override
  void onStateTransition(
      JumpSquatState from, JumpSquatState to, int timestampMs) {
    // Chuyển từ hạ gối tiếp đất sang đứng thẳng -> Chốt sổ đánh giá
    if (from == JumpSquatState.landing &&
        to == JumpSquatState.standing &&
        !_evaluated) {
      _evaluateLanding(
          RepContext); // RepContext ở đây lấy tham chiếu gián tiếp, nhưng ta dùng biến local
      _evaluated = true;
    }
  }

  void _evaluateLanding(Type repContextType) {
    if (_minLandingKneeAngle == null) return;

    final angle = _minLandingKneeAngle!;
    const phase = 'REP_COMPLETE';

    if (angle > LandingConfig.STIFF_LANDING_MIN) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Knee',
        message:
            'Tiếp đất chân quá thẳng (${angle.toStringAsFixed(0)}°)! Nguy hiểm khớp gối.',
        affectsForm: true, // Hủy rep, tính là form hỏng nặng
      ));
    } else if (angle > LandingConfig.SAFE_FLEXION_MAX) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'Knee',
        message:
            'Tiếp đất chưa đủ sâu (${angle.toStringAsFixed(0)}°). Hãy trùng gối thêm!',
        affectsForm: false, // Cảnh báo
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _minLandingKneeAngle = null;
    _evaluated = false;
  }
}
