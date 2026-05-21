/* =========================================================================
   Metric 2: Anti-Rotation / Rolling (Chống vặn xoắn)
   Priority: 🔴 CRITICAL — Bảo vệ đĩa đệm (McGill)
   ========================================================================= */

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'side_plank_dip_metric_base.dart';

class RotationConfig {
  static const double TWIST_THRESHOLD = 0.7; // Rút ngắn còn 70% = vặn mình
}

class AntiRotationMetric extends SidePlankDipMetricBase {
  @override
  String get name => 'AntiRotation';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double _baselineShoulderWidth = 0;
  double _baselineHipWidth = 0;
  bool _baselineCaptured = false;
  
  bool _hasTwisted = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;
  
  // Được gọi từ main class lúc isInStartPosition
  void captureBaseline(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lS = landmarks[PoseLandmarkType.leftShoulder];
    final rS = landmarks[PoseLandmarkType.rightShoulder];
    final lH = landmarks[PoseLandmarkType.leftHip];
    final rH = landmarks[PoseLandmarkType.rightHip];
    
    if (lS != null && rS != null && lH != null && rH != null) {
      _baselineShoulderWidth = (lS.x - rS.x).abs();
      _baselineHipWidth = (lH.x - rH.x).abs();
      _baselineCaptured = true;
    }
  }

  @override
  void update(RepContext ctx) {
    if (!_baselineCaptured) return;
    
    // Nếu khoảng cách bị thu hẹp đáng kể, chứng tỏ người dùng đang xoay ra trước/sau so với camera
    if (ctx.shoulderWidthX < _baselineShoulderWidth * RotationConfig.TWIST_THRESHOLD || 
        ctx.hipWidthX < _baselineHipWidth * RotationConfig.TWIST_THRESHOLD) {
      _hasTwisted = true;
      ctx.resultIssues.feedback['Core'] = 'Đừng đổ người! Giữ hông vuông góc.';
    }
  }

  @override
  void onStateTransition(SidePlankState from, SidePlankState to, int timestampMs) {
    if (to == SidePlankState.top && _hasTwisted) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'Core',
        message: 'Lỗi vặn mình. Cơ thể không được đổ về trước hoặc sau!',
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _hasTwisted = false;
  }
}