import 'dart:math' as math;

import 'sit_up_metric_base.dart';

class StabilityMetric extends SitUpMetricBase {
  @override
  String get name => 'LowerBodyStability';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  double? _startAnkleX;
  double? _startAnkleY;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(SitUpState from, SitUpState to, int timestampMs) {
    if (to == SitUpState.rising) {
      _startAnkleX = null;
      _startAnkleY = null;
    }
  }

  @override
  void update(SitUpRepContext ctx) {
    if (ctx.state == SitUpState.lying) return;

    _startAnkleX ??= ctx.ankleX;
    _startAnkleY ??= ctx.ankleY;
    if (ctx.scaleFactor != null) {
      final dx = ctx.ankleX - _startAnkleX!;
      final dy = ctx.ankleY - _startAnkleY!;
      final deviation = math.sqrt(dx * dx + dy * dy) / ctx.scaleFactor!;

      if (deviation > 0.22 && !_faults.any((f) => f.type == 'Stability')) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Stability',
          message: 'Nhấc chân khỏi sàn',
          voiceMessage: 'Hạ chân xuống',
          affectsForm: true,
          priority: SitUpFaultPriority.heelLift,
        ));
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _startAnkleX = null;
    _startAnkleY = null;
  }
}
