import 'v_up_metric_base.dart';

class SyncElevationMetric extends VUpMetricBase {
  @override
  String get name => 'SyncElevation';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  
  double? _baselineShoulderY;
  double? _baselineAnkleY;
  bool _evaluatedThisRep = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onStateTransition(VUpState from, VUpState to, int timestampMs) {
    if (from == VUpState.lying && to == VUpState.rising) {
       _evaluatedThisRep = false;
    }
  }

  @override
  void update(VUpRepContext ctx) {
    if (ctx.state == VUpState.lying) {
      _baselineShoulderY = ctx.shoulderY;
      _baselineAnkleY = ctx.ankleY;
      return;
    }

    if (ctx.state == VUpState.rising && !_evaluatedThisRep && ctx.scaleFactor != null && _baselineShoulderY != null) {
      // Y hướng xuống sàn. Nhấc lên -> Y giảm.
      double shoulderLift = (_baselineShoulderY! - ctx.shoulderY) / ctx.scaleFactor!;
      double ankleLift = (_baselineAnkleY! - ctx.ankleY) / ctx.scaleFactor!;
      
      _debugData['shldLift'] = shoulderLift.toStringAsFixed(2);
      _debugData['ankleLift'] = ankleLift.toStringAsFixed(2);

      // Nếu một bên đã nâng đáng kể (> 15% chiều dài lưng) mà bên kia vẫn chưa nâng (< 5%)
      bool shoulderLead = shoulderLift > 0.15 && ankleLift < 0.05;
      bool ankleLead = ankleLift > 0.15 && shoulderLift < 0.05;

      if (shoulderLead || ankleLead) {
        _faults.add(FaultRecord(
          phase: ctx.state.name,
          type: 'AsyncElevation',
          message: 'Mất đồng bộ thân trên và chi dưới',
          voiceMessage: 'Hãy nâng cả tay và chân CÙNG LÚC để bảo vệ lưng!',
          affectsForm: true,
          priority: VUpFaultPriority.syncElevation,
        ));
        _evaluatedThisRep = true; // Chỉ log 1 lần mỗi rep
      }
      
      // Nếu cả 2 đều đã lên quá 15% mà không dính lỗi -> form tốt, bỏ qua đánh giá tiếp
      if (shoulderLift > 0.15 && ankleLift > 0.15) {
        _evaluatedThisRep = true;
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _evaluatedThisRep = false;
  }
}