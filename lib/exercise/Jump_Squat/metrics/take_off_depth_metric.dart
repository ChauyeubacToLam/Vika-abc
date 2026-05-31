/* =========================================================================
   Metric 2: Take-Off Depth (Biên độ lấy đà)
   Priority: 🟡 MEDIUM — Hiệu suất sức mạnh bùng nổ
   
   Nếu góc lấy đà cạn (> 90 độ), bài tập biến thành Calf Jump, mất đi
   tác dụng plyometric cho đùi và mông.
   ========================================================================= */

import 'jump_squat_metric_base.dart';

class TakeOffConfig {
  static const double GOOD_DEPTH_MIN = 70.0;
  static const double GOOD_DEPTH_MAX = 90.0;
  static const double SHALLOW_WARNING = 100.0;
}

class TakeOffDepthMetric extends JumpSquatMetricBase {
  @override
  String get name => 'TakeOffDepth';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double? _minSquatAngle;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.jumpSquatState == JumpSquatState.squatting) {
      if (_minSquatAngle == null || ctx.kneeAngle < _minSquatAngle!) {
        _minSquatAngle = ctx.kneeAngle;
      }
      _debugData['takeOffDepth'] = _minSquatAngle?.toStringAsFixed(1) ?? '-';
    }
  }

  @override
  void onStateTransition(
      JumpSquatState from, JumpSquatState to, int timestampMs) {
    // Chốt góc lấy đà khi bắt đầu bung người phóng lên
    if (from == JumpSquatState.squatting && to == JumpSquatState.launching) {
      if (_minSquatAngle != null &&
          _minSquatAngle! > TakeOffConfig.SHALLOW_WARNING) {
        _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'Power',
          message:
              'Lấy đà quá nông (${_minSquatAngle!.toStringAsFixed(0)}°). Hạ hông sâu hơn!',
          affectsForm: false,
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _minSquatAngle = null;
  }
}
