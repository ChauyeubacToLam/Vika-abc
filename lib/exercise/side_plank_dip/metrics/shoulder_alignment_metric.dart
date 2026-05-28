/* =========================================================================
   Metric 1: Shoulder/Elbow Alignment (Trục tay trụ)
   Priority: 🔴 CRITICAL — Bảo vệ khớp vai (Rotator Cuff)
   ========================================================================= */

import 'side_plank_dip_metric_base.dart';

class ShoulderConfig {
  static const double OFFSET_WARNING = 10.0; // Khoảng lệch tương đối
  static const double OFFSET_DANGER = 18.0; 
}

class ShoulderAlignmentMetric extends SidePlankDipMetricBase {
  @override
  String get name => 'ShoulderAlignment';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  double? _maxOffsetX;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (_maxOffsetX == null || ctx.shoulderElbowOffsetX > _maxOffsetX!) {
      _maxOffsetX = ctx.shoulderElbowOffsetX;
    }
    
    if (ctx.shoulderElbowOffsetX > ShoulderConfig.OFFSET_DANGER) {
      ctx.resultIssues.feedback['Shoulder'] = 'RÚT TAY LẠI! Khuỷu tay phải nằm dưới vai.';
    }
  }

  @override
  void onStateTransition(SidePlankState from, SidePlankState to, int timestampMs) {
    if (to == SidePlankState.top && _maxOffsetX != null) {
      if (_maxOffsetX! > ShoulderConfig.OFFSET_DANGER) {
        _faults.add(FaultRecord(
          phase: 'REP_COMPLETE',
          type: 'Shoulder',
          message: 'Khuỷu tay lệch trục quá xa! Rủi ro chấn thương vai.',
          affectsForm: true,
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _maxOffsetX = null;
  }
}