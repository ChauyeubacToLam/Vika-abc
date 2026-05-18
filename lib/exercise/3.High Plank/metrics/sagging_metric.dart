import 'high_plank_metric_base.dart';
import '../high_plank.dart';

class SaggingMetric extends HighPlankMetricBase {
  @override
  String get name => 'SaggingHips';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  bool _isFaulting = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(HighPlankRepContext ctx) {
    _debugData['hipDev'] = ctx.hipDeviation.toStringAsFixed(3);

    if (ctx.hipDeviation > HighPlankConfig.DROPPING_SAG_DEVIATION) {
      // UI feedback hiển thị mọi lúc để hướng dẫn user
      ctx.resultIssues.feedback['Core'] = 'Võng lưng!';

      // FIX Bug 4: Chỉ ghi fault record khi đang HOLDING.
      // Khi SETUP: user chưa vào vị trí, không nên tính lỗi.
      // Khi DROPPING: state đã phản ánh mất form rồi, fault mới không có thêm giá trị.
      if (ctx.state == HighPlankState.holding && !_isFaulting) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'Sagging',
          message: 'Võng lưng gây áp lực cột sống',
          voiceMessage: 'Siết chặt bụng, nâng hông lên một chút',
          affectsForm: true,
          priority: HighPlankFaultPriority.hipSagging,
        ));
        _isFaulting = true;
      }
    } else {
      ctx.resultIssues.feedback['Core'] = 'Lưng phẳng';
      _isFaulting = false;
    }
  }

  @override
  void reset() {}
}