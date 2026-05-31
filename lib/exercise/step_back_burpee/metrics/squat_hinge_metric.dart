/* =========================================================================
   Metric 1: Spinal Flexion vs Hip Hinge (Cúi lưng vs Trùng gối)
   Priority: 🔴 CRITICAL — Bảo vệ đĩa đệm cột sống
   
   Medical Note (McGill): Cúi người bằng cách gập cong cột sống với đầu gối
   thẳng đứng tạo ra lực nén (compressive load) cực lớn lên đĩa đệm.
   Người dùng PHẢI gập gối (< 100 độ) để hạ trọng tâm xuống.
   ========================================================================= */

import 'step_back_burpee_metric_base.dart';

class SquatHingeConfig {
  static const double SAFE_KNEE_FLEXION = 100.0; // Gối gập sâu, an toàn
  static const double STIFF_LEG_DANGER = 150.0; // Chân đơ thẳng, nguy hiểm
}

class SquatHingeMetric extends StepBackBurpeeMetricBase {
  @override
  String get name => 'SquatHinge';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _minKneeAngleDuringSquat;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.burpeeState == BurpeeState.squattingDown ||
        ctx.burpeeState == BurpeeState.steppingBack) {
      if (_minKneeAngleDuringSquat == null ||
          ctx.kneeAngle < _minKneeAngleDuringSquat!) {
        _minKneeAngleDuringSquat = ctx.kneeAngle;
      }
      _debugData['squatKnee'] =
          _minKneeAngleDuringSquat?.toStringAsFixed(1) ?? '-';

      // Live feedback
      if (ctx.kneeAngle > SquatHingeConfig.STIFF_LEG_DANGER) {
        ctx.resultIssues.feedback['Back'] = 'Trùng gối xuống! Đừng cúi lưng.';
      }
    }
  }

  @override
  void onStateTransition(BurpeeState from, BurpeeState to, int timestampMs) {
    // Chốt đánh giá khi đã vào tư thế Plank
    if (to == BurpeeState.highPlank) {
      if (_minKneeAngleDuringSquat != null) {
        if (_minKneeAngleDuringSquat! > SquatHingeConfig.STIFF_LEG_DANGER) {
          _faults.add(FaultRecord(
            phase: 'REP_COMPLETE',
            type: 'Spine',
            message:
                'Lỗi nguy hiểm: Cúi gập lưng với chân thẳng. Hãy trùng gối!',
            affectsForm: true,
          ));
        } else if (_minKneeAngleDuringSquat! >
            SquatHingeConfig.SAFE_KNEE_FLEXION) {
          _faults.add(FaultRecord(
            phase: 'REP_COMPLETE',
            type: 'Spine',
            message: 'Hạ hông và gập gối sâu hơn nữa khi chạm đất.',
            affectsForm: false,
          ));
        }
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _minKneeAngleDuringSquat = null;
  }
}
